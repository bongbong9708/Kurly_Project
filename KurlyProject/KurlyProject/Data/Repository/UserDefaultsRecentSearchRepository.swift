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
        // 실패한다면 코드가 잘못된 것이라 디버그 빌드에서는 멈춰서 드러내고,
        // 릴리스 빌드에서는 최근 검색어 저장 하나 때문에 앱을 죽이지 않도록 저장만 건너뛴다
        do {
            let data = try JSONEncoder().encode(searches.map(RecentSearchDTO.init))
            userDefaults.set(data, forKey: Self.storageKey)
        } catch {
            assertionFailure("최근 검색어 인코딩 실패: \(error)")
        }
    }
}
