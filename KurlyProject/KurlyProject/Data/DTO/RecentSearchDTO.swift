//
//  RecentSearchDTO.swift
//  KurlyProject
//

import Foundation

/// 최근 검색어의 저장 형식.
///
/// Domain Entity와 분리한 이유: Entity 프로퍼티 이름을 바꿔도 저장된 데이터의 키는 그대로 남아,
/// 기존 사용자의 최근 검색어를 잃지 않는다. 저장 형식을 바꿀 때는 여기와 변환만 고치면 된다.
struct RecentSearchDTO: Codable {
    let keyword: String
    let searchedAt: Date
}

extension RecentSearchDTO {
    init(_ entity: RecentSearch) {
        self.init(keyword: entity.keyword, searchedAt: entity.searchedAt)
    }

    func toDomain() -> RecentSearch {
        RecentSearch(keyword: keyword, searchedAt: searchedAt)
    }
}
