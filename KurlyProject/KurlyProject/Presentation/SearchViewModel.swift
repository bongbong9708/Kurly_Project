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

    var query = ""
    private(set) var state: State = .idle

    /// 진행 중인 검색. 재검색 시 취소하려고 들고 있는다.
    /// 테스트가 검색이 끝날 때까지 기다릴 수 있도록 읽기는 열어 둔다.
    private(set) var searchTask: Task<Void, Never>?

    private let repository: SearchResultRepository

    init(repository: SearchResultRepository) {
        self.repository = repository
    }

    /// iOS 18 이하에서 해제 시 크래시를 막기 위해 deinit을 메인 액터 밖에서 실행한다.
    ///
    /// 빌드 설정(기본 액터 격리 MainActor + Approachable Concurrency)에서는 deinit이 메인 액터로
    /// 옮겨져 실행되는데, 이를 구버전 OS에서 돌리는 호환 코드(BackDeploy)가 iOS 18.6 시뮬레이터에서
    /// SIGABRT로 죽었다 (iOS 27.1에서는 정상). deinit에서 하는 일이 없으므로 격리가 필요 없다.
    nonisolated deinit {}

    func search() {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }

        searchTask?.cancel()
        state = .loading

        searchTask = Task {
            do {
                let result = try await repository.search(keyword: keyword, page: 1)
                // 취소를 무시하고 늦게 돌아온 이전 요청이 최신 결과를 덮어쓰지 않게 막는다
                guard !Task.isCancelled else { return }
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
