//
//  UserDefaultsRecentSearchRepository.swift
//  KurlyProject
//

import Foundation

/// `RecentSearchRepository`의 UserDefaults 구현. 목록 전체를 JSON 한 덩어리로 저장한다.
struct UserDefaultsRecentSearchRepository: RecentSearchRepository {

    static let storageKey = "recentSearches"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func fetch() -> [RecentSearch] {
        guard let data = userDefaults.data(forKey: Self.storageKey) else { return [] }
        // 저장 형식이 바뀌었거나 데이터가 깨졌으면 빈 목록으로 시작한다.
        // 최근 검색어는 잃어도 앱 사용에 지장이 없고, 다음 저장 때 덮어써진다.
        guard let dtos = try? JSONDecoder().decode([RecentSearchDTO].self, from: data) else { return [] }
        return dtos.map { $0.toDomain() }
    }

    func save(_ searches: [RecentSearch]) {
        // String과 Date만 담긴 배열이라 인코딩은 실패하지 않는다.
        // 실패한다면 코드가 잘못된 것이라 크래시로 드러내는 편이 낫다
        let data = try! JSONEncoder().encode(searches.map(RecentSearchDTO.init))
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
