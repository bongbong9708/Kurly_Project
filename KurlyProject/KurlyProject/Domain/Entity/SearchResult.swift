//
//  SearchResult.swift
//  KurlyProject
//

import Foundation

/// 검색 한 페이지의 응답.
///
/// `totalCount`는 개별 저장소가 아니라 응답 전체에 붙는 값이라 여기에 둔다.
/// 페이지마다 같은 값이 내려온다.
struct SearchResult: Equatable {
    let totalCount: Int
    let repositories: [GitHubRepository]
}
