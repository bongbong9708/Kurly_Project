//
//  HTTPClient.swift
//  KurlyProject
//

import Foundation

/// 네트워크 호출 경계.
///
/// `URLSession`을 직접 쓰지 않고 한 겹 감싼 이유는 테스트 때문이다.
/// 403, 429, 디코딩 실패 같은 응답을 실제 서버 없이 주입하려면 갈아끼울 지점이 필요하다.
protocol HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}
