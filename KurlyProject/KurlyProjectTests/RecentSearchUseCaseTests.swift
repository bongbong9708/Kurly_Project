//
//  RecentSearchUseCaseTests.swift
//  KurlyProjectTests
//

import XCTest
@testable import KurlyProject

/// 메모리에만 저장하는 테스트 대역. 정책은 UseCase가 갖고 있으므로 저장소는 받은 그대로 둔다.
private final class InMemoryRecentSearchRepository: RecentSearchRepository {
    var searches: [RecentSearch] = []

    func fetch() -> [RecentSearch] { searches }
    func save(_ searches: [RecentSearch]) { self.searches = searches }
}

final class RecentSearchUseCaseTests: XCTestCase {

    private var repository: InMemoryRecentSearchRepository!
    private var currentTime: TimeInterval = 0
    private var sut: RecentSearchUseCase!

    override func setUp() {
        super.setUp()
        repository = InMemoryRecentSearchRepository()
        currentTime = 0
        // 저장할 때마다 1초씩 흐르는 시계. 저장 순서가 곧 시간 순서가 된다
        sut = RecentSearchUseCase(repository: repository, now: { [unowned self] in
            currentTime += 1
            return Date(timeIntervalSince1970: currentTime)
        })
    }

    private var keywords: [String] {
        sut.fetch().map(\.keyword)
    }

    func test_저장한_검색어를_시각과_함께_돌려준다() {
        sut.save(keyword: "swift")

        XCTAssertEqual(sut.fetch(), [RecentSearch(keyword: "swift", searchedAt: Date(timeIntervalSince1970: 1))])
    }

    func test_최근에_검색한_순서로_정렬한다() {
        sut.save(keyword: "a")
        sut.save(keyword: "b")
        sut.save(keyword: "c")

        XCTAssertEqual(keywords, ["c", "b", "a"])
    }

    // MARK: - 10개 제한

    func test_11번째를_저장하면_가장_오래된_항목이_사라진다() {
        (1...10).forEach { sut.save(keyword: "keyword\($0)") }

        sut.save(keyword: "keyword11")

        XCTAssertEqual(keywords.count, 10)
        XCTAssertEqual(keywords.first, "keyword11")
        XCTAssertFalse(keywords.contains("keyword1"))
    }

    func test_10개가_찬_상태에서_중복을_저장하면_아무것도_삭제되지_않는다() {
        (1...10).forEach { sut.save(keyword: "keyword\($0)") }

        sut.save(keyword: "keyword1")

        XCTAssertEqual(keywords.count, 10)
        XCTAssertEqual(Set(keywords), Set((1...10).map { "keyword\($0)" }))
    }

    // MARK: - 중복

    func test_대소문자만_다른_검색어는_새로_추가하지_않는다() {
        sut.save(keyword: "Swift")
        sut.save(keyword: "kotlin")

        sut.save(keyword: "swift")

        XCTAssertEqual(keywords.count, 2)
    }

    func test_중복이면_새로_입력한_표기와_시각으로_갱신하고_맨_앞으로_온다() {
        sut.save(keyword: "Swift")   // 1초
        sut.save(keyword: "kotlin")  // 2초

        sut.save(keyword: "swift")   // 3초

        XCTAssertEqual(sut.fetch().first, RecentSearch(keyword: "swift", searchedAt: Date(timeIntervalSince1970: 3)))
    }
}
