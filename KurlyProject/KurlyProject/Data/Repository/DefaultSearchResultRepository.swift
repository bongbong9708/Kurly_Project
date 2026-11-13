//
//  DefaultSearchResultRepository.swift
//  KurlyProject
//

import Foundation

/// `SearchResultRepository`의 네트워크 구현.
///
/// API Client가 돌려준 DTO를 Entity로 바꾸는 것 외에는 하는 일이 없다.
/// 이 얇은 층이 있어서 Domain이 DTO와 HTTP를 모른 채로 남는다.
struct DefaultSearchResultRepository: SearchResultRepository {

    private let apiClient: GitHubSearchAPIClient

    init(apiClient: GitHubSearchAPIClient = GitHubSearchAPIClient()) {
        self.apiClient = apiClient
    }

    func search(keyword: String, page: Int) async throws -> SearchResult {
        try await apiClient.search(keyword: keyword, page: page).toDomain()
    }
}
