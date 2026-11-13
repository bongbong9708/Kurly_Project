//
//  SearchResultDTOTests.swift
//  KurlyProjectTests
//

import XCTest
@testable import KurlyProject

final class SearchResultDTOTests: XCTestCase {

    /// 실제 API 응답(`q=swift&page=1`)에서 쓰는 필드만 남긴 고정 데이터
    private func loadFixture() throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(
            bundle.url(forResource: "search_repositories_swift", withExtension: "json")
        )
        return try Data(contentsOf: url)
    }

    func test_실제_응답을_DTO로_디코딩한다() throws {
        let dto = try JSONDecoder().decode(SearchResultDTO.self, from: loadFixture())

        XCTAssertEqual(dto.totalCount, 441722)
        XCTAssertEqual(dto.items.count, 3)
        XCTAssertEqual(dto.items[0].name, "swift")
        XCTAssertEqual(dto.items[0].owner.login, "swiftlang")
    }

    func test_DTO를_Entity로_변환한다() throws {
        let dto = try JSONDecoder().decode(SearchResultDTO.self, from: loadFixture())

        let result = dto.toDomain()

        XCTAssertEqual(result.totalCount, 441722)
        XCTAssertEqual(result.repositories.count, 3)

        let first = try XCTUnwrap(result.repositories.first)
        XCTAssertEqual(first.id, 44838949)
        XCTAssertEqual(first.name, "swift")
        XCTAssertEqual(first.ownerLogin, "swiftlang")
        XCTAssertEqual(first.htmlURL, URL(string: "https://github.com/swiftlang/swift"))
        XCTAssertEqual(
            first.ownerAvatarURL,
            URL(string: "https://avatars.githubusercontent.com/u/42816656?v=4")
        )
    }

    func test_항목_순서가_응답_순서와_같다() throws {
        let dto = try JSONDecoder().decode(SearchResultDTO.self, from: loadFixture())

        let logins = dto.toDomain().repositories.map(\.ownerLogin)

        XCTAssertEqual(logins, ["swiftlang", "openstack", "tensorflow"])
    }

    func test_total_count키가_없으면_디코딩에_실패한다() throws {
        let json = Data(#"{"items": []}"#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(SearchResultDTO.self, from: json))
    }

    func test_html_url키가_없으면_디코딩에_실패한다() throws {
        let json = Data(#"""
        {
          "total_count": 1,
          "items": [
            {
              "id": 1,
              "name": "no-url",
              "owner": { "login": "a", "avatar_url": "https://example.com/a.png" }
            }
          ]
        }
        """#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(SearchResultDTO.self, from: json))
    }

    func test_html_url이_빈_문자열이면_디코딩에_실패한다() throws {
        // URL(string:)이 nil을 돌려주는 거의 유일한 입력이 빈 문자열이다
        let json = Data(#"""
        {
          "total_count": 1,
          "items": [
            {
              "id": 1,
              "name": "empty-url",
              "html_url": "",
              "owner": { "login": "a", "avatar_url": "https://example.com/a.png" }
            }
          ]
        }
        """#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(SearchResultDTO.self, from: json))
    }
}
