//
//  GitHubSearchAPIClientTests.swift
//  KurlyProjectTests
//

import XCTest
@testable import KurlyProject

/// 지정한 응답이나 에러를 그대로 돌려주는 테스트 대역.
/// 마지막으로 받은 요청을 남겨서 URL이 제대로 만들어졌는지도 확인한다.
private final class MockHTTPClient: HTTPClient {
    var result: Result<(Data, URLResponse), Error>
    private(set) var lastRequest: URLRequest?

    init(result: Result<(Data, URLResponse), Error>) {
        self.result = result
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        return try result.get()
    }
}

private func httpResponse(_ statusCode: Int) -> URLResponse {
    HTTPURLResponse(
        url: URL(string: "https://api.github.com")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

final class GitHubSearchAPIClientTests: XCTestCase {

    private let validJSON = Data(#"""
    {
      "total_count": 2,
      "items": [
        {
          "id": 1,
          "name": "swift",
          "html_url": "https://github.com/swiftlang/swift",
          "owner": { "login": "swiftlang", "avatar_url": "https://example.com/a.png" }
        }
      ]
    }
    """#.utf8)

    private func makeClient(
        _ result: Result<(Data, URLResponse), Error>
    ) -> (GitHubSearchAPIClient, MockHTTPClient) {
        let mock = MockHTTPClient(result: result)
        return (GitHubSearchAPIClient(client: mock), mock)
    }

    // MARK: - 요청

    func test_키워드와_페이지가_쿼리에_담긴다() async throws {
        let (sut, mock) = makeClient(.success((validJSON, httpResponse(200))))

        _ = try await sut.search(keyword: "swift", page: 3)

        let url = try XCTUnwrap(mock.lastRequest?.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "api.github.com")
        XCTAssertEqual(components.path, "/search/repositories")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "q" })?.value, "swift")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "page" })?.value, "3")
    }

    func test_공백이_있는_키워드도_쿼리에_담긴다() async throws {
        let (sut, mock) = makeClient(.success((validJSON, httpResponse(200))))

        _ = try await sut.search(keyword: "ios swift", page: 1)

        let url = try XCTUnwrap(mock.lastRequest?.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "q" })?.value, "ios swift")
    }

    // MARK: - 성공

    func test_200이면_DTO를_돌려준다() async throws {
        let (sut, _) = makeClient(.success((validJSON, httpResponse(200))))

        let dto = try await sut.search(keyword: "swift", page: 1)

        XCTAssertEqual(dto.totalCount, 2)
        XCTAssertEqual(dto.items.count, 1)
    }

    // MARK: - 실패

    func test_연결이_안_되면_network_에러() async {
        let urlError = URLError(.notConnectedToInternet)
        let (sut, _) = makeClient(.failure(urlError))

        await assertThrows(.network) { try await sut.search(keyword: "swift", page: 1) }
    }

    func test_403이면_rateLimited_에러() async {
        let (sut, _) = makeClient(.success((Data(), httpResponse(403))))

        await assertThrows(.rateLimited) { try await sut.search(keyword: "swift", page: 1) }
    }

    func test_429면_rateLimited_에러() async {
        let (sut, _) = makeClient(.success((Data(), httpResponse(429))))

        await assertThrows(.rateLimited) { try await sut.search(keyword: "swift", page: 1) }
    }

    func test_200이지만_형태가_다르면_decoding_에러() async {
        let (sut, _) = makeClient(.success((Data(#"{"unexpected": true}"#.utf8), httpResponse(200))))

        await assertThrows(.decoding) { try await sut.search(keyword: "swift", page: 1) }
    }

    func test_URLSession이_취소를_알리면_cancelled_에러() async {
        let (sut, _) = makeClient(.failure(URLError(.cancelled)))

        await assertThrows(.cancelled) { try await sut.search(keyword: "swift", page: 1) }
    }

    func test_Task가_취소되면_cancelled_에러() async {
        let (sut, _) = makeClient(.failure(CancellationError()))

        await assertThrows(.cancelled) { try await sut.search(keyword: "swift", page: 1) }
    }

    func test_취소는_network_에러와_구분된다() async {
        // 새 검색어 입력으로 이전 요청을 취소했을 때 네트워크 에러로 보이면 안 된다
        let (cancelledSUT, _) = makeClient(.failure(URLError(.cancelled)))
        let (offlineSUT, _) = makeClient(.failure(URLError(.notConnectedToInternet)))

        await assertThrows(.cancelled) { try await cancelledSUT.search(keyword: "swift", page: 1) }
        await assertThrows(.network) { try await offlineSUT.search(keyword: "swift", page: 1) }
    }

    func test_그_밖의_상태코드는_코드를_담아서_전달한다() async {
        let (sut, _) = makeClient(.success((Data(), httpResponse(422))))

        await assertThrows(.unexpectedStatus(422)) { try await sut.search(keyword: "swift", page: 1) }
    }

    // MARK: - Helper

    private func assertThrows(
        _ expected: SearchError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("에러가 발생하지 않았다", file: file, line: line)
        } catch let error as SearchError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("SearchError가 아닌 에러: \(error)", file: file, line: line)
        }
    }
}
