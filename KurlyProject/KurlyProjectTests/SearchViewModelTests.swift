//
//  SearchViewModelTests.swift
//  KurlyProjectTests
//

import XCTest
@testable import KurlyProject

/// 받은 키워드를 기록하고, `handler`로 지정한 결과를 돌려주는 테스트 대역.
private final class MockSearchResultRepository: SearchResultRepository {
    var handler: (String, Int) async throws -> SearchResult = { _, _ in
        SearchResult(totalCount: 0, repositories: [])
    }
    private(set) var receivedKeywords: [String] = []
    private(set) var receivedPages: [Int] = []

    func search(keyword: String, page: Int) async throws -> SearchResult {
        receivedKeywords.append(keyword)
        receivedPages.append(page)
        return try await handler(keyword, page)
    }
}

private final class InMemoryRecentSearchRepository: RecentSearchRepository {
    var searches: [RecentSearch] = []

    func fetch() -> [RecentSearch] { searches }
    func save(_ searches: [RecentSearch]) { self.searches = searches }
}

@MainActor
final class SearchViewModelTests: XCTestCase {

    private var repository: MockSearchResultRepository!
    private var recentSearchRepository: InMemoryRecentSearchRepository!
    private var currentTime: TimeInterval = 0
    private var sut: SearchViewModel!

    override func setUp() {
        super.setUp()
        repository = MockSearchResultRepository()
        recentSearchRepository = InMemoryRecentSearchRepository()
        sut = makeSUT()
    }

    private func makeSUT() -> SearchViewModel {
        SearchViewModel(
            repository: repository,
            // 연달아 저장해도 시각이 겹치지 않도록 저장할 때마다 1초씩 흐르는 시계를 쓴다
            recentSearchUseCase: RecentSearchUseCase(repository: recentSearchRepository, now: { [unowned self] in
                currentTime += 1
                return Date(timeIntervalSince1970: currentTime)
            })
        )
    }

    private func makeResult(totalCount: Int) -> SearchResult {
        SearchResult(
            totalCount: totalCount,
            repositories: [
                GitHubRepository(
                    id: totalCount,
                    name: "repo\(totalCount)",
                    ownerLogin: "owner",
                    ownerAvatarURL: URL(string: "https://example.com/a.png")!,
                    htmlURL: URL(string: "https://github.com/owner/repo")!
                )
            ]
        )
    }

    // MARK: - 성공

    func test_검색하면_loading을_거쳐_결과를_보여준다() async {
        let result = makeResult(totalCount: 1)
        repository.handler = { _, _ in result }
        sut.query = "swift"

        sut.search()
        XCTAssertEqual(sut.state, .loading)

        await sut.searchTask?.value
        XCTAssertEqual(sut.state, .loaded(result))
    }

    func test_첫_페이지를_요청한다() async {
        var receivedPage: Int?
        repository.handler = { _, page in
            receivedPage = page
            return SearchResult(totalCount: 0, repositories: [])
        }
        sut.query = "swift"

        sut.search()
        await sut.searchTask?.value

        XCTAssertEqual(receivedPage, 1)
    }

    // MARK: - 입력 처리

    func test_검색어_앞뒤_공백은_잘라서_요청한다() async {
        sut.query = "  swift  "

        sut.search()
        await sut.searchTask?.value

        XCTAssertEqual(repository.receivedKeywords, ["swift"])
    }

    func test_공백만_있으면_검색하지_않는다() async {
        sut.query = "   "

        sut.search()
        await sut.searchTask?.value

        XCTAssertTrue(repository.receivedKeywords.isEmpty)
        XCTAssertEqual(sut.state, .idle)
        XCTAssertTrue(sut.recentSearches.isEmpty)
    }

    // MARK: - 최근 검색어

    func test_생성할_때_저장된_최근_검색어를_불러온다() {
        let saved = [RecentSearch(keyword: "swift", searchedAt: Date(timeIntervalSince1970: 100))]
        recentSearchRepository.searches = saved

        XCTAssertEqual(makeSUT().recentSearches, saved)
    }

    func test_검색하면_공백을_잘라낸_검색어가_최근_검색어에_추가된다() {
        sut.query = "  swift  "

        sut.search()

        // 검색 완료를 기다리지 않는다. 검색을 실행한 순간 저장한다
        XCTAssertEqual(sut.recentSearches.map(\.keyword), ["swift"])
        XCTAssertEqual(recentSearchRepository.searches.map(\.keyword), ["swift"])
    }

    func test_최근_검색어를_고르면_그_키워드로_검색한다() async {
        let result = makeResult(totalCount: 1)
        repository.handler = { _, _ in result }

        sut.search(keyword: "swift")

        XCTAssertEqual(sut.query, "swift")
        await sut.searchTask?.value
        XCTAssertEqual(repository.receivedKeywords, ["swift"])
        XCTAssertEqual(sut.state, .loaded(result))
    }

    func test_최근_검색어를_고르면_목록_맨_위로_올라온다() {
        sut.query = "swift"
        sut.search()
        sut.query = "kotlin"
        sut.search()

        sut.search(keyword: "swift")

        XCTAssertEqual(sut.recentSearches.map(\.keyword), ["swift", "kotlin"])
    }

    func test_최근_검색어를_삭제하면_목록에서_사라진다() {
        sut.query = "swift"
        sut.search()
        sut.query = "kotlin"
        sut.search()

        sut.delete(keyword: "swift")

        XCTAssertEqual(sut.recentSearches.map(\.keyword), ["kotlin"])
        XCTAssertEqual(recentSearchRepository.searches.map(\.keyword), ["kotlin"])
    }

    func test_최근_검색어를_전체_삭제하면_목록이_빈다() {
        sut.query = "swift"
        sut.search()

        sut.deleteAll()

        XCTAssertTrue(sut.recentSearches.isEmpty)
        XCTAssertTrue(recentSearchRepository.searches.isEmpty)
    }

    func test_검색이_실패해도_최근_검색어에는_저장한다() async {
        repository.handler = { _, _ in throw SearchError.network }
        sut.query = "swift"

        sut.search()
        await sut.searchTask?.value

        XCTAssertEqual(sut.recentSearches.map(\.keyword), ["swift"])
    }

    // MARK: - 실패

    func test_검색이_실패하면_에러를_보여준다() async {
        repository.handler = { _, _ in throw SearchError.rateLimited }
        sut.query = "swift"

        sut.search()
        await sut.searchTask?.value

        XCTAssertEqual(sut.state, .failed(.rateLimited))
    }

    // MARK: - 다시 시도

    func test_다시_시도하면_같은_검색어로_다시_요청한다() async {
        let result = makeResult(totalCount: 1)
        var shouldFail = true
        repository.handler = { _, _ in
            if shouldFail { throw SearchError.network }
            return result
        }
        sut.query = "swift"
        sut.search()
        await sut.searchTask?.value

        shouldFail = false
        sut.retry()
        await sut.searchTask?.value

        XCTAssertEqual(repository.receivedKeywords, ["swift", "swift"])
        XCTAssertEqual(sut.state, .loaded(result))
    }

    func test_다시_시도는_검색바를_고쳤어도_실패한_검색어로_요청한다() async {
        // 검색어를 고친 뒤 검색하지 않고 키보드만 내리면 에러 화면이 남은 채 검색바 글자만 달라진다.
        // 다음 페이지와 같이, 화면에 보이는 결과(에러)의 검색어로 다시 요청해야 한다
        var shouldFail = true
        repository.handler = { _, _ in
            if shouldFail { throw SearchError.network }
            return self.makeResult(totalCount: 1)
        }
        sut.query = "swift"
        sut.search()
        await sut.searchTask?.value

        sut.query = "swif"
        shouldFail = false
        sut.retry()
        await sut.searchTask?.value

        XCTAssertEqual(repository.receivedKeywords, ["swift", "swift"])
    }

    func test_다시_시도는_최근_검색어를_다시_저장하지_않는다() async {
        repository.handler = { _, _ in throw SearchError.network }
        sut.query = "swift"
        sut.search()
        await sut.searchTask?.value
        let before = sut.recentSearches

        sut.retry()
        await sut.searchTask?.value

        XCTAssertEqual(sut.recentSearches, before)
        XCTAssertEqual(recentSearchRepository.searches, before)
    }

    // MARK: - 자동완성

    func test_자동완성은_최근_검색어_중_입력을_포함하는_것만_최신순으로_보여준다() {
        sut.search(keyword: "SwiftUI")
        sut.search(keyword: "kotlin")
        sut.search(keyword: "swift")

        sut.query = "swi"

        XCTAssertEqual(sut.suggestions.map(\.keyword), ["swift", "SwiftUI"])
    }

    // MARK: - 검색어 비우기 (취소)

    func test_검색어를_비우면_idle로_돌아간다() async {
        repository.handler = { _, _ in self.makeResult(totalCount: 1) }
        sut.query = "swift"
        sut.search()
        await sut.searchTask?.value

        sut.query = ""

        XCTAssertEqual(sut.state, .idle)
    }

    func test_검색_중에_검색어를_비우면_늦게_온_결과로_덮어쓰지_않는다() async {
        var release: CheckedContinuation<Void, Never>?
        repository.handler = { _, _ in
            await withCheckedContinuation { release = $0 }
            return self.makeResult(totalCount: 1)
        }
        sut.query = "swift"
        sut.search()
        let task = sut.searchTask
        while release == nil { await Task.yield() }

        sut.query = ""
        release?.resume()
        await task?.value

        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - 재검색

    func test_이전_검색이_늦게_끝나도_마지막_검색_결과를_보여준다() async {
        // 이전 요청이 취소를 무시하고 성공으로 돌아오는 최악의 경우를 흉내낸다
        let oldResult = makeResult(totalCount: 1)
        let newResult = makeResult(totalCount: 2)
        var releaseOld: CheckedContinuation<Void, Never>?
        repository.handler = { keyword, _ in
            if keyword == "old" {
                await withCheckedContinuation { releaseOld = $0 }
                return oldResult
            }
            return newResult
        }

        sut.query = "old"
        sut.search()
        let oldTask = sut.searchTask
        while releaseOld == nil { await Task.yield() }

        sut.query = "new"
        sut.search()
        await sut.searchTask?.value

        releaseOld?.resume()
        await oldTask?.value

        XCTAssertEqual(sut.state, .loaded(newResult))
    }

    func test_이전_검색이_취소돼도_에러를_보여주지_않는다() async {
        // 실제 URLSession은 취소되면 SearchError.cancelled를 던진다
        let newResult = makeResult(totalCount: 2)
        var releaseOld: CheckedContinuation<Void, Never>?
        repository.handler = { keyword, _ in
            if keyword == "old" {
                await withCheckedContinuation { releaseOld = $0 }
                throw SearchError.cancelled
            }
            return newResult
        }

        sut.query = "old"
        sut.search()
        let oldTask = sut.searchTask
        while releaseOld == nil { await Task.yield() }

        sut.query = "new"
        sut.search()
        await sut.searchTask?.value

        releaseOld?.resume()
        await oldTask?.value

        XCTAssertEqual(sut.state, .loaded(newResult))
    }

    // MARK: - 다음 페이지

    private func makePage(ids: Range<Int>, totalCount: Int) -> SearchResult {
        SearchResult(
            totalCount: totalCount,
            repositories: ids.map { id in
                GitHubRepository(
                    id: id,
                    name: "repo\(id)",
                    ownerLogin: "owner",
                    ownerAvatarURL: URL(string: "https://example.com/a.png")!,
                    htmlURL: URL(string: "https://github.com/owner/repo\(id)")!
                )
            }
        )
    }

    /// 첫 페이지 검색을 끝내고, 화면에 보이는 저장소 목록을 돌려준다
    private func searchFirstPage(keyword: String = "swift") async -> [GitHubRepository] {
        sut.query = keyword
        sut.search()
        await sut.searchTask?.value
        return loadedRepositories
    }

    private var loadedRepositories: [GitHubRepository] {
        guard case .loaded(let result) = sut.state else { return [] }
        return result.repositories
    }

    func test_끝에서_5번째_이내의_행이_보이면_다음_페이지를_이어_붙인다() async {
        repository.handler = { _, page in
            page == 1 ? self.makePage(ids: 0..<30, totalCount: 100) : self.makePage(ids: 30..<60, totalCount: 100)
        }
        let repositories = await searchFirstPage()

        sut.loadNextPageIfNeeded(currentItem: repositories[25])
        await sut.nextPageTask?.value

        XCTAssertEqual(repository.receivedPages, [1, 2])
        XCTAssertEqual(loadedRepositories.map(\.id), Array(0..<60))
    }

    func test_끝에서_5번째보다_앞의_행이면_요청하지_않는다() async {
        repository.handler = { _, _ in self.makePage(ids: 0..<30, totalCount: 100) }
        let repositories = await searchFirstPage()

        sut.loadNextPageIfNeeded(currentItem: repositories[24])

        XCTAssertEqual(repository.receivedPages, [1])
    }

    func test_다음_페이지를_불러오는_중에는_추가로_요청하지_않는다() async {
        var release: CheckedContinuation<Void, Never>?
        repository.handler = { _, page in
            if page == 2 { await withCheckedContinuation { release = $0 } }
            return self.makePage(ids: (page - 1) * 30..<page * 30, totalCount: 100)
        }
        let repositories = await searchFirstPage()

        sut.loadNextPageIfNeeded(currentItem: repositories[29])
        while release == nil { await Task.yield() }
        XCTAssertEqual(sut.nextPageState, .loading)
        sut.loadNextPageIfNeeded(currentItem: repositories[29])
        release?.resume()
        await sut.nextPageTask?.value

        XCTAssertEqual(repository.receivedPages, [1, 2])
    }

    func test_전체를_다_받았으면_요청하지_않는다() async {
        repository.handler = { _, _ in self.makePage(ids: 0..<30, totalCount: 30) }
        let repositories = await searchFirstPage()

        sut.loadNextPageIfNeeded(currentItem: repositories[29])

        XCTAssertEqual(repository.receivedPages, [1])
    }

    func test_1000개를_받았으면_전체_개수가_더_많아도_요청하지_않는다() async {
        // GitHub 검색은 1,000개까지만 돌려주고 그 뒤 페이지는 422로 실패한다
        repository.handler = { _, _ in self.makePage(ids: 0..<1000, totalCount: 5000) }
        let repositories = await searchFirstPage()

        sut.loadNextPageIfNeeded(currentItem: repositories[999])

        XCTAssertEqual(repository.receivedPages, [1])
    }

    func test_빈_페이지를_받으면_더_요청하지_않는다() async {
        repository.handler = { _, page in
            page == 1 ? self.makePage(ids: 0..<30, totalCount: 100) : self.makePage(ids: 0..<0, totalCount: 100)
        }
        let repositories = await searchFirstPage()
        sut.loadNextPageIfNeeded(currentItem: repositories[29])
        await sut.nextPageTask?.value

        sut.loadNextPageIfNeeded(currentItem: repositories[29])

        XCTAssertEqual(repository.receivedPages, [1, 2])
    }

    func test_다음_페이지가_실패해도_받은_결과는_유지한다() async {
        repository.handler = { _, page in
            if page == 2 { throw SearchError.network }
            return self.makePage(ids: 0..<30, totalCount: 100)
        }
        let repositories = await searchFirstPage()

        sut.loadNextPageIfNeeded(currentItem: repositories[29])
        await sut.nextPageTask?.value

        XCTAssertEqual(loadedRepositories.map(\.id), Array(0..<30))
        XCTAssertEqual(sut.nextPageState, .failed(.network))
    }

    func test_다음_페이지가_실패하면_스크롤로는_다시_요청하지_않고_다시_시도로_요청한다() async {
        var shouldFail = true
        repository.handler = { _, page in
            if page == 2 && shouldFail { throw SearchError.rateLimited }
            return self.makePage(ids: (page - 1) * 30..<page * 30, totalCount: 100)
        }
        let repositories = await searchFirstPage()
        sut.loadNextPageIfNeeded(currentItem: repositories[29])
        await sut.nextPageTask?.value

        sut.loadNextPageIfNeeded(currentItem: repositories[29])
        XCTAssertEqual(repository.receivedPages, [1, 2])

        shouldFail = false
        sut.retryNextPage()
        await sut.nextPageTask?.value

        XCTAssertEqual(repository.receivedPages, [1, 2, 2])
        XCTAssertEqual(loadedRepositories.count, 60)
        XCTAssertEqual(sut.nextPageState, .idle)
    }

    func test_새로_검색하면_이전_검색의_다음_페이지_결과가_섞이지_않는다() async {
        var releaseOld: CheckedContinuation<Void, Never>?
        let newResult = makePage(ids: 100..<130, totalCount: 100)
        repository.handler = { keyword, page in
            if keyword == "old" && page == 2 {
                await withCheckedContinuation { releaseOld = $0 }
                return self.makePage(ids: 30..<60, totalCount: 100)
            }
            return keyword == "old" ? self.makePage(ids: 0..<30, totalCount: 100) : newResult
        }
        let repositories = await searchFirstPage(keyword: "old")
        sut.loadNextPageIfNeeded(currentItem: repositories[29])
        let oldNextPageTask = sut.nextPageTask
        while releaseOld == nil { await Task.yield() }

        sut.query = "new"
        sut.search()
        await sut.searchTask?.value
        releaseOld?.resume()
        await oldNextPageTask?.value

        XCTAssertEqual(sut.state, .loaded(newResult))
        XCTAssertEqual(sut.nextPageState, .idle)
    }

    func test_다음_페이지에_이미_받은_저장소가_있으면_빼고_붙인다() async {
        // 검색 결과는 요청 사이에 순서가 바뀔 수 있어 다음 페이지에 앞 페이지 항목이 다시 올 수 있다
        repository.handler = { _, page in
            page == 1 ? self.makePage(ids: 0..<30, totalCount: 100) : self.makePage(ids: 25..<55, totalCount: 100)
        }
        let repositories = await searchFirstPage()

        sut.loadNextPageIfNeeded(currentItem: repositories[29])
        await sut.nextPageTask?.value

        XCTAssertEqual(loadedRepositories.map(\.id), Array(0..<55))
    }

    func test_다음_페이지는_검색바를_고쳤더라도_검색했던_검색어로_요청한다() async {
        repository.handler = { _, page in self.makePage(ids: (page - 1) * 30..<page * 30, totalCount: 100) }
        let repositories = await searchFirstPage()

        // 검색어를 고친 뒤 검색하지 않고 결과를 계속 스크롤한 경우
        sut.query = "swif"
        sut.loadNextPageIfNeeded(currentItem: repositories[29])
        await sut.nextPageTask?.value

        XCTAssertEqual(repository.receivedKeywords, ["swift", "swift"])
    }
}
