//
//  SearchViewModel.swift
//  KurlyProject
//

import Foundation
import Observation

/// 검색 화면의 상태와 검색 실행.
///
/// 검색은 단순 위임이라 UseCase 없이 Repository를 직접 호출한다.
@Observable
@MainActor
final class SearchViewModel {

    /// 화면이 보여줄 상태.
    ///
    /// 프로퍼티 여러 개(`isLoading`, `result`, `error`) 대신 enum으로 둔 이유:
    /// "로딩 중이면서 에러" 같은 동시에 있을 수 없는 조합을 타입으로 막는다.
    enum State: Equatable {
        case idle
        case loading
        case loaded(SearchResult)
        case failed(SearchError)
    }

    /// 다음 페이지 상태. 첫 검색 상태(`State`)와 따로 둔다.
    ///
    /// 다음 페이지가 실패해도 이미 받은 결과는 그대로 보여줘야 하므로 `State`를 `.failed`로 바꾸지 않는다
    enum NextPageState: Equatable {
        case idle
        case loading
        case failed(SearchError)
    }

    /// GitHub 검색 API는 결과를 1,000개까지만 돌려준다. 그 뒤 페이지를 요청하면 422로 실패한다
    static let maxResultCount = 1000

    /// 끝에서 몇 번째 행이 보일 때 다음 페이지를 미리 요청할지.
    /// 한 페이지 30개 중 25번째쯤에서 요청해 끝에 닿기 전에 응답이 오게 한다
    static let prefetchThreshold = 5

    var query = "" {
        didSet {
            // 검색바의 "취소"(또는 지우기 버튼)로 검색어가 비면 검색 전 상태로 돌아간다.
            // 진행 중인 요청도 취소해 늦게 온 결과가 idle을 덮어쓰지 않게 한다
            if query.isEmpty && !oldValue.isEmpty {
                searchTask?.cancel()
                resetPagination()
                state = .idle
            }
        }
    }
    private(set) var state: State = .idle

    /// 진행 중인 검색. 재검색 시 취소하려고 들고 있는다.
    /// 테스트가 검색이 끝날 때까지 기다릴 수 있도록 읽기는 열어 둔다.
    private(set) var searchTask: Task<Void, Never>?

    private(set) var nextPageState: NextPageState = .idle

    /// 진행 중인 다음 페이지 요청. 새 검색 시 취소하려고 들고 있는다. 테스트가 기다릴 수 있도록 읽기는 열어 둔다
    private(set) var nextPageTask: Task<Void, Never>?

    /// 지금 보여주는 결과(또는 에러)의 검색어. 검색 후 검색바를 고쳐도 다시 시도·다음 페이지는 이 검색어로 요청해야 해서 따로 둔다
    private var currentKeyword: String?
    private var currentPage = 1
    /// 중복을 빼기 전, 서버에서 받은 항목 수. 1,000개 제한과 비교하는 데 쓴다
    private var receivedCount = 0
    private var hasNextPage = false

    private(set) var recentSearches: [RecentSearch]

    /// 입력을 포함하는 최근 검색어 (자동완성)
    var suggestions: [RecentSearch] {
        recentSearchUseCase.suggestions(for: query, in: recentSearches)
    }

    private let repository: SearchResultRepository
    private let recentSearchUseCase: RecentSearchUseCase

    init(repository: SearchResultRepository, recentSearchUseCase: RecentSearchUseCase) {
        self.repository = repository
        self.recentSearchUseCase = recentSearchUseCase
        self.recentSearches = recentSearchUseCase.fetch()
    }

    /// iOS 18 이하에서 해제 시 크래시를 막기 위해 deinit을 메인 액터 밖에서 실행한다.
    ///
    /// 빌드 설정(기본 액터 격리 MainActor + Approachable Concurrency)에서는 deinit이 메인 액터로
    /// 옮겨져 실행되는데, 이를 구버전 OS에서 돌리는 호환 코드(BackDeploy)가 iOS 18.6 시뮬레이터에서
    /// SIGABRT로 죽었다 (iOS 27.1에서는 정상). deinit에서 하는 일이 없으므로 격리가 필요 없다.
    nonisolated deinit {}

    func delete(keyword: String) {
        recentSearchUseCase.delete(keyword: keyword)
        recentSearches = recentSearchUseCase.fetch()
    }

    func deleteAll() {
        recentSearchUseCase.deleteAll()
        recentSearches = recentSearchUseCase.fetch()
    }

    /// 최근 검색어를 골랐을 때. 직접 입력한 검색과 같은 흐름(저장·시각 갱신 포함)을 탄다
    func search(keyword: String) {
        query = keyword
        search()
    }

    func search() {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }

        // 검색 결과와 상관없이 검색을 실행한 순간 저장한다
        recentSearchUseCase.save(keyword: keyword)
        recentSearches = recentSearchUseCase.fetch()

        load(keyword: keyword)
    }

    /// 실패한 검색을 같은 검색어로 다시 요청한다.
    ///
    /// 사용자가 새로 검색한 것이 아니므로 최근 검색어를 다시 저장하지 않는다.
    /// 검색바 글자가 아니라 검색했던 검색어(`currentKeyword`)로 요청한다. 검색어를 고친 뒤 키보드만 내리면
    /// 검색바 글자가 달라질 수 있는데, 화면의 에러는 검색했던 검색어의 것이기 때문이다 (다음 페이지와 같은 기준)
    func retry() {
        guard let keyword = currentKeyword else { return }
        load(keyword: keyword)
    }

    /// 보이기 시작한 행이 끝에서 `prefetchThreshold`번째 안쪽이면 다음 페이지를 요청한다.
    ///
    /// 로딩 중이거나 실패한 상태에서는 요청하지 않는다. 실패 후 스크롤할 때마다 다시 요청하지 않도록
    /// 다시 요청은 `retryNextPage()`로만 한다
    func loadNextPageIfNeeded(currentItem: GitHubRepository) {
        guard case .loaded(let result) = state,
              let index = result.repositories.firstIndex(where: { $0.id == currentItem.id }),
              index >= result.repositories.count - Self.prefetchThreshold
        else { return }
        loadNextPage()
    }

    func retryNextPage() {
        guard case .failed = nextPageState else { return }
        nextPageState = .idle
        loadNextPage()
    }

    private func loadNextPage() {
        guard hasNextPage, nextPageState == .idle, let keyword = currentKeyword else { return }
        let page = currentPage + 1
        nextPageState = .loading

        nextPageTask = Task {
            do {
                let next = try await repository.search(keyword: keyword, page: page)
                // 새 검색이 시작돼 취소됐으면 이전 검색어의 결과를 섞지 않는다
                guard !Task.isCancelled, case .loaded(let current) = state else { return }

                // 요청 사이에 검색 결과 순서가 바뀌면 앞 페이지 항목이 다시 올 수 있다.
                // 같은 id가 두 번 있으면 List가 행을 구분하지 못하므로 빼고 붙인다
                let loadedIDs = Set(current.repositories.map(\.id))
                let newRepositories = next.repositories.filter { !loadedIDs.contains($0.id) }
                state = .loaded(SearchResult(
                    totalCount: current.totalCount,
                    repositories: current.repositories + newRepositories
                ))
                currentPage = page
                updateHasNextPage(totalCount: current.totalCount, lastPage: next)
                nextPageState = .idle
            } catch {
                guard !Task.isCancelled else { return }
                nextPageState = .failed(error as? SearchError ?? .network)
            }
        }
    }

    /// 받은 개수가 전체(최대 1,000개)보다 적고, 마지막으로 받은 페이지가 비어 있지 않으면 다음 페이지가 있다
    private func updateHasNextPage(totalCount: Int, lastPage: SearchResult) {
        receivedCount += lastPage.repositories.count
        hasNextPage = !lastPage.repositories.isEmpty
            && receivedCount < min(totalCount, Self.maxResultCount)
    }

    private func resetPagination() {
        nextPageTask?.cancel()
        nextPageState = .idle
        currentPage = 1
        receivedCount = 0
        hasNextPage = false
    }

    private func load(keyword: String) {
        searchTask?.cancel()
        resetPagination()
        currentKeyword = keyword
        state = .loading

        searchTask = Task {
            do {
                let result = try await repository.search(keyword: keyword, page: 1)
                // 취소를 무시하고 늦게 돌아온 이전 요청이 최신 결과를 덮어쓰지 않게 막는다
                guard !Task.isCancelled else { return }
                updateHasNextPage(totalCount: result.totalCount, lastPage: result)
                state = .loaded(result)
            } catch {
                // 취소는 새 검색이 시작됐다는 뜻이다. 상태는 새 검색이 관리한다
                guard !Task.isCancelled else { return }
                // Repository는 SearchError만 던지도록 되어 있다
                state = .failed(error as? SearchError ?? .network)
            }
        }
    }
}
