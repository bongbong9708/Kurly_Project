//
//  SearchErrorMessageTests.swift
//  KurlyProjectTests
//

import XCTest
@testable import KurlyProject

final class SearchErrorMessageTests: XCTestCase {

    func test_네트워크_에러와_한도_초과는_서로_다른_안내를_한다() {
        XCTAssertNotEqual(SearchError.network.message, SearchError.rateLimited.message)
        XCTAssertNotEqual(SearchError.network.message, SearchError.decoding.message)
        XCTAssertNotEqual(SearchError.rateLimited.message, SearchError.decoding.message)
    }

    func test_사용자가_할_수_있는_대응이_같은_에러는_같은_안내를_한다() {
        // 디코딩 실패와 예상 밖 응답은 사용자 입장에서 둘 다 "잠시 후 다시"뿐이다
        XCTAssertEqual(SearchError.decoding.title, SearchError.unexpectedStatus(500).title)
        XCTAssertEqual(SearchError.decoding.message, SearchError.unexpectedStatus(500).message)
    }
}
