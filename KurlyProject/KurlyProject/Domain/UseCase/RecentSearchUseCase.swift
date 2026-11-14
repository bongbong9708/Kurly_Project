//
//  RecentSearchUseCase.swift
//  KurlyProject
//

import Foundation

/// 최근 검색어 정책.
///
/// - 대소문자만 다른 검색어는 같은 검색어로 보고, 새 표기와 시각으로 갱신한다
/// - 마지막 검색 시각 기준 최신순으로 저장한다
/// - 10개까지만 저장한다. 넘치면 가장 오래된 항목을 버린다
///
/// 정렬된 상태로 저장하므로 `fetch()`는 읽은 그대로 돌려준다.
/// 저장소를 쓰는 곳이 이 UseCase 하나뿐이라 순서가 깨질 경로가 없다.
struct RecentSearchUseCase {

    static let maxCount = 10

    private let repository: RecentSearchRepository
    private let now: () -> Date

    /// - Parameter now: 테스트에서 시각을 고정하려고 주입받는다
    init(repository: RecentSearchRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    func fetch() -> [RecentSearch] {
        repository.fetch()
    }

    /// - Parameter keyword: 앞뒤 공백을 잘라낸 비어 있지 않은 검색어. trim은 호출하는 쪽(ViewModel)에서 한다
    func save(keyword: String) {
        var searches = repository.fetch()
        // 중복은 지우고 새로 넣는다. 갱신이 곧 "삭제 + 추가"라 개수가 늘지 않아 10개 제한에 걸리지 않는다
        searches.removeAll { $0.keyword.caseInsensitiveCompare(keyword) == .orderedSame }
        searches.append(RecentSearch(keyword: keyword, searchedAt: now()))
        searches.sort { $0.searchedAt > $1.searchedAt }
        repository.save(Array(searches.prefix(Self.maxCount)))
    }
}
