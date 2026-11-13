//
//  SearchError.swift
//  KurlyProject
//

import Foundation

/// 검색 중 일어날 수 있는 실패.
///
/// HTTP 상태 코드를 Presentation까지 올려보내지 않기 위해 Data 레이어에서 이 타입으로 바꾼다.
/// 화면은 상태 코드가 아니라 이 case로 분기한다.
enum SearchError: Error, Equatable {
    /// 네트워크 연결 없음
    case network

    /// 요청 한도 초과. 인증 없는 GitHub Search API는 한도가 낮아 실제로 자주 걸린다 (403 / 429)
    case rateLimited

    /// 응답은 왔지만 우리가 아는 형태가 아님
    case decoding

    /// 위 셋에 해당하지 않는 응답. 어떤 코드였는지는 디버깅을 위해 남긴다
    case unexpectedStatus(Int)
}
