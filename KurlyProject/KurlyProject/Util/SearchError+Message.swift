//
//  SearchError+Message.swift
//  KurlyProject
//

import Foundation

/// 에러 화면에 보여줄 안내.
///
/// 화면 문구라서 Domain의 `SearchError` 본체에 넣지 않고 확장으로 따로 둔다.
/// 사용자가 할 수 있는 대응이 다른 경우만 문구를 나눈다.
extension SearchError {

    var title: String {
        switch self {
        case .network: "인터넷에 연결되어 있지 않습니다"
        case .rateLimited: "요청이 너무 많습니다"
        case .decoding, .unexpectedStatus, .cancelled: "검색 결과를 불러오지 못했습니다"
        }
    }

    var message: String {
        switch self {
        case .network: "연결 상태를 확인하고 다시 시도해 주세요."
        case .rateLimited: "잠시 후 다시 시도해 주세요."
        // cancelled는 화면에 나오지 않는다. switch를 빠짐없이 채우려고 같은 문구로 묶었다
        case .decoding, .unexpectedStatus, .cancelled: "일시적인 오류입니다. 다시 시도해 주세요."
        }
    }

    var systemImage: String {
        switch self {
        case .network: "wifi.slash"
        case .rateLimited: "clock"
        case .decoding, .unexpectedStatus, .cancelled: "exclamationmark.triangle"
        }
    }
}
