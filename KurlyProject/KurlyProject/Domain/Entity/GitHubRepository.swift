//
//  GitHubRepository.swift
//  KurlyProject
//

import Foundation

/// 검색 결과로 보여줄 GitHub 저장소.
///
/// 이름에 `GitHub` 접두사를 붙인 이유: Clean Architecture에서 데이터 접근 프로토콜도
/// `...Repository`로 부르기 때문에, 저장소 "데이터"와 혼동되지 않게 구분했다.
///
/// `Hashable`은 `NavigationLink(value:)`로 화면 전환 값으로 넘기기 위해 필요하다.
struct GitHubRepository: Identifiable, Hashable {
    let id: Int
    let name: String
    let ownerLogin: String
    let ownerAvatarURL: URL
    let htmlURL: URL
}
