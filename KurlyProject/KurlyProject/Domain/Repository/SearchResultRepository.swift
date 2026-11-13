//
//  SearchResultRepository.swift
//  KurlyProject
//

import Foundation

/// 저장소 검색 결과를 가져오는 경계.
///
/// Domain은 이 프로토콜만 알고, 실제로 네트워크를 쓰는지 캐시를 쓰는지는 모른다.
/// 실패는 전부 `SearchError`로 올라온다.
protocol SearchResultRepository {
    func search(keyword: String, page: Int) async throws -> SearchResult
}
