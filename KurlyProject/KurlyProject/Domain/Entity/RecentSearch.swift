//
//  RecentSearch.swift
//  KurlyProject
//

import Foundation

/// 최근 검색어 한 건.
///
/// `searchedAt`은 마지막으로 검색한 시각이다. 같은 검색어를 다시 검색하면
/// 새로 추가하지 않고 이 값만 갱신하므로, 정렬 기준이자 중복 판정의 결과값이 된다.
struct RecentSearch: Equatable {
    let keyword: String
    let searchedAt: Date
}
