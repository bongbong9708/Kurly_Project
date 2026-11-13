//
//  GitHubSearchAPIClient.swift
//  KurlyProject
//

import Foundation

/// GitHub 저장소 검색 API 호출.
///
/// 이 타입이 HTTP 상태 코드와 `URLError`를 `SearchError`로 바꾼다.
/// 위 레이어는 상태 코드를 모른 채 `SearchError`만 보고 분기한다.
struct GitHubSearchAPIClient {

    private let client: HTTPClient

    init(client: HTTPClient = URLSession.shared) {
        self.client = client
    }

    func search(keyword: String, page: Int) async throws -> SearchResultDTO {
        let request = URLRequest(url: makeURL(keyword: keyword, page: page))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await client.data(for: request)
        } catch is CancellationError {
            throw SearchError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            // URLSession은 Task 취소를 URLError(.cancelled)로 바꿔서 던진다
            throw SearchError.cancelled
        } catch {
            // 연결 실패와 타임아웃. 사용자가 할 수 있는 대응이 같아 하나로 묶는다
            throw SearchError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw SearchError.decoding
        }

        switch http.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(SearchResultDTO.self, from: data)
            } catch {
                throw SearchError.decoding
            }
        case 403, 429:
            // 인증 없는 Search API는 한도가 낮아 실제로 자주 걸린다
            throw SearchError.rateLimited
        default:
            throw SearchError.unexpectedStatus(http.statusCode)
        }
    }

    /// 쿼리 인코딩은 `URLComponents`에 맡긴다.
    ///
    /// 구성 요소가 전부 상수이고 `keyword`도 `queryItems`를 거치며 인코딩되므로
    /// URL 생성은 실패하지 않는다. 실패한다면 코드가 잘못된 것이라 크래시로 드러내는 편이 낫다.
    private func makeURL(keyword: String, page: Int) -> URL {
        var components = URLComponents(string: "https://api.github.com/search/repositories")!
        components.queryItems = [
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "page", value: String(page))
        ]
        return components.url!
    }
}
