//
//  SearchResultDTO.swift
//  KurlyProject
//

import Foundation

/// `GET /search/repositories` 응답을 그대로 받는 타입.
///
/// Domain Entity와 분리한 이유: 응답 형태가 바뀌어도 Domain은 그대로 두고 여기와 변환만 고치면 된다.
struct SearchResultDTO: Decodable {
    let totalCount: Int
    let items: [RepositoryDTO]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}

/// URL 필드를 `String`이 아니라 `URL`로 받는다.
///
/// GitHub이 절대 URL을 준다는 계약을 신뢰하고, 어기면 디코딩 단계에서 실패하게 둔다.
/// 항목마다 URL 유효성을 따로 검사하지 않는 이유는 `URL(string:)`이 거의 모든 문자열을
/// 상대 URL로 받아들여서, 그 검사가 실질적으로 아무것도 걸러내지 못하기 때문이다.
struct RepositoryDTO: Decodable {
    let id: Int
    let name: String
    let htmlURL: URL
    let owner: OwnerDTO

    enum CodingKeys: String, CodingKey {
        case id, name, owner
        case htmlURL = "html_url"
    }
}

struct OwnerDTO: Decodable {
    let login: String
    let avatarURL: URL

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
    }
}

extension SearchResultDTO {
    func toDomain() -> SearchResult {
        SearchResult(
            totalCount: totalCount,
            repositories: items.map { item in
                GitHubRepository(
                    id: item.id,
                    name: item.name,
                    ownerLogin: item.owner.login,
                    ownerAvatarURL: item.owner.avatarURL,
                    htmlURL: item.htmlURL
                )
            }
        )
    }
}
