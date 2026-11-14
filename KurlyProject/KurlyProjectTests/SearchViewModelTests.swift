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

    func search(keyword: String, page: Int) async throws -> SearchResult {
        receivedKeywords.append(keyword)
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
            recentSearchUseCase: RecentSearchUseCase(repository: recentSearchRepository)
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
}
