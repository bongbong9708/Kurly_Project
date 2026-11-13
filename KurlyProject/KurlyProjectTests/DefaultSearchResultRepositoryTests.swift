//
//  DefaultSearchResultRepositoryTests.swift
//  KurlyProjectTests
//

import XCTest
@testable import KurlyProject

/// Repository는 API Client를 감싸 DTO를 Entity로 바꾸는 층이다.
/// 그래서 검증할 것은 두 가지뿐이다: 변환이 맞는가, 에러가 그대로 올라오는가.
final class DefaultSearchResultRepositoryTests: XCTestCase {

    private final class StubHTTPClient: HTTPClient {
        let result: Result<(Data, URLResponse), Error>

        init(result: Result<(Data, URLResponse), Error>) {
            self.result = result
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            try result.get()
        }
    }

    private func makeSUT(
        _ result: Result<(Data, URLResponse), Error>
    ) -> DefaultSearchResultRepository {
        DefaultSearchResultRepository(
            apiClient: GitHubSearchAPIClient(client: StubHTTPClient(result: result))
        )
    }

    private func okResponse() -> URLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.github.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    func test_응답을_Entity로_바꿔서_돌려준다() async throws {
        let json = Data(#"""
        {
          "total_count": 120,
          "items": [
            {
              "id": 44838949,
              "name": "swift",
              "html_url": "https://github.com/swiftlang/swift",
              "owner": {
                "login": "swiftlang",
                "avatar_url": "https://avatars.githubusercontent.com/u/42816656?v=4"
              }
            }
          ]
        }
        """#.utf8)
        let sut = makeSUT(.success((json, okResponse())))

        let result = try await sut.search(keyword: "swift", page: 1)

        XCTAssertEqual(result.totalCount, 120)
        let first = try XCTUnwrap(result.repositories.first)
        XCTAssertEqual(first.id, 44838949)
        XCTAssertEqual(first.name, "swift")
        XCTAssertEqual(first.ownerLogin, "swiftlang")
        XCTAssertEqual(first.htmlURL, URL(string: "https://github.com/swiftlang/swift"))
    }

    func test_결과가_비어도_성공으로_돌려준다() async throws {
        let json = Data(#"{"total_count": 0, "items": []}"#.utf8)
        let sut = makeSUT(.success((json, okResponse())))

        let result = try await sut.search(keyword: "ㅁㄴㅇㄹ", page: 1)

        XCTAssertEqual(result.totalCount, 0)
        XCTAssertTrue(result.repositories.isEmpty)
    }

    func test_API_Client의_에러를_그대로_올려보낸다() async {
        let sut = makeSUT(.failure(URLError(.notConnectedToInternet)))

        do {
            _ = try await sut.search(keyword: "swift", page: 1)
            XCTFail("에러가 발생하지 않았다")
        } catch let error as SearchError {
            XCTAssertEqual(error, .network)
        } catch {
            XCTFail("SearchError가 아닌 에러: \(error)")
        }
    }
}
