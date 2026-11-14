//
//  RecentSearchRepository.swift
//  KurlyProject
//

import Foundation

/// 최근 검색어 목록을 저장하고 읽는 경계.
///
/// 목록 전체를 읽고 쓰는 것만 맡는다. 중복 갱신·10개 제한·정렬 같은 정책은 UseCase에 둔다.
/// 그래야 저장 방식을 바꿔도(예: SwiftData) 정책 코드를 다시 쓰지 않는다.
protocol RecentSearchRepository {
    func fetch() -> [RecentSearch]
    func save(_ searches: [RecentSearch])
}
