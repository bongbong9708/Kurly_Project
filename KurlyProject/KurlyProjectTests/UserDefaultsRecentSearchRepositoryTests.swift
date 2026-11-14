//
//  UserDefaultsRecentSearchRepositoryTests.swift
//  KurlyProjectTests
//

import XCTest
@testable import KurlyProject

/// 저장소는 목록을 그대로 저장하고 읽는다. 중복·10개 제한 같은 정책은 검증하지 않는다 (UseCase 몫).
final class UserDefaultsRecentSearchRepositoryTests: XCTestCase {

    private let suiteName = "UserDefaultsRecentSearchRepositoryTests"
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // 실제 앱 데이터(.standard)를 건드리지 않도록 테스트 전용 저장소를 쓴다
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeSUT() -> UserDefaultsRecentSearchRepository {
        UserDefaultsRecentSearchRepository(userDefaults: userDefaults)
    }

    func test_저장한_적이_없으면_빈_목록() {
        XCTAssertEqual(makeSUT().fetch(), [])
    }

    func test_저장한_목록을_새_인스턴스로_읽어도_순서까지_같다() {
        // 앱 재시작을 새 인스턴스 생성으로 흉내낸다
        let searches = [
            RecentSearch(keyword: "swift", searchedAt: Date(timeIntervalSince1970: 200)),
            RecentSearch(keyword: "kotlin", searchedAt: Date(timeIntervalSince1970: 100))
        ]

        makeSUT().save(searches)

        XCTAssertEqual(makeSUT().fetch(), searches)
    }

    func test_다시_저장하면_이전_목록을_덮어쓴다() {
        let sut = makeSUT()
        sut.save([RecentSearch(keyword: "swift", searchedAt: Date(timeIntervalSince1970: 100))])

        sut.save([])

        XCTAssertEqual(sut.fetch(), [])
    }

    func test_저장된_데이터를_읽을_수_없으면_빈_목록() {
        // 저장 형식이 바뀌었거나 데이터가 깨진 경우
        userDefaults.set(Data("not json".utf8), forKey: UserDefaultsRecentSearchRepository.storageKey)

        XCTAssertEqual(makeSUT().fetch(), [])
    }
}
