# 02. API Client와 Repository (Issue #1, PR #18)

## 목표

GitHub 검색 API를 호출하고, HTTP 상태 코드와 네트워크 실패를 `SearchError`로 바꾼다.
실제 서버 없이 실패 상황을 테스트할 수 있게 만든다.
Domain이 DTO와 HTTP를 모르도록 Repository 경계를 만든다.

## 프롬프트

> Presentation 폴더 및 swift 파일 이동해주고
> API Clitent까지 진행하고 커밋할거야

> Repository까지 하고 PR

> usecase, viewmodel, ui 등은 다음 이슈에서 만들고 지금은 pr 올라온 부분만 체크하면 되니?

> 설계 지점 설명해줘

> cancelled 처리를 지금하자 나머지는 추후 수정해도 될거같아

## AI 응답 요약

- `ContentView.swift`를 `Presentation/`으로 `git mv`
  - `KurlyProjectApp.swift`는 화면이 아니라 앱 진입점이라 루트에 두는 것으로 가정하고 진행 (확인 요청함)
- `HTTPClient` 프로토콜로 네트워크 경계를 만듦
  - 시그니처를 `URLSession`의 기존 메서드와 동일하게 맞춰 `extension URLSession: HTTPClient {}` 한 줄로 구현 완료
- `GitHubSearchAPIClient`에서 상태 코드를 `SearchError`로 변환
  - 호출 실패 → `.network` / 200 + 디코딩 실패 → `.decoding`
  - 403, 429 → `.rateLimited` / 그 외 → `.unexpectedStatus(코드)`
- `makeURL`에서 강제 언래핑(`!`)을 사용. 구성 요소가 전부 상수라 실패 시 코드 결함이므로
  감추지 말고 크래시로 드러내는 편이 낫다고 판단한 뒤 주석으로 근거를 남김 (확인 요청함)
- `MockHTTPClient`로 상태 코드를 주입하는 테스트 8개 작성
- `SearchResultRepository`(Domain 프로토콜) + `DefaultSearchResultRepository`(Data 구현) 추가
  - 구현 본문이 한 줄뿐이라 원칙 2에 걸릴 수 있다는 점을 먼저 밝힘
  - 그래도 둔 이유: 이 층이 없으면 ViewModel이 `SearchResultDTO`와 `toDomain()`을 알게 되어 레이어가 샌다

- PR 리뷰 지점을 설명하다가 **직접 쓴 코드에서 문제 두 개를 발견**
  - `URLQueryItem`이 쿼리의 `+`를 인코딩하지 않아 `c++` 검색이 `c  `로 나갈 수 있음 → 이슈 #2에서 처리하기로 보류
  - 모든 호출 실패를 `.network`로 묶어서, 이전 요청 취소(`URLError(.cancelled)`)까지 네트워크 에러로 표시됨
    → 새 검색어를 입력할 때마다 에러 화면이 뜨는 동작이 됨
- 취소 표현 방식을 두 가지로 제시: `SearchError.cancelled` 추가 vs `CancellationError` 그대로 전파

## 내가 판단·수정한 것

| AI 제안 | 문제 | 수정 | 이유 |
|---|---|---|---|
| 모든 호출 실패를 `.network` 하나로 묶음 | 요청 취소까지 네트워크 에러가 되어, 새 검색어 입력 시 에러 화면이 뜸 | `SearchError.cancelled` 추가, `CancellationError`와 `URLError(.cancelled)` 둘 다 잡음 |  |
| `+` 인코딩 문제, 403/429 구분, 한글 테스트명 | 지금 고칠 필요는 없다고 판단 | 보류 |  |

## 검증

- 테스트: 전체 22개 통과 (DTO 6, API Client 11, Repository 3, 템플릿 기본 2)
  - 쿼리 생성: 키워드·페이지가 담기는지, 공백 있는 키워드 처리
  - 성공: 200이면 DTO 반환
  - 실패: 연결 실패 / 403 / 429 / 형태 불일치 / 그 외 상태 코드(422)
  - 취소: `URLError(.cancelled)`, `CancellationError`, 그리고 취소와 연결 실패가 섞이지 않는지
  - Repository: Entity 변환, 빈 결과도 성공 처리, 에러를 삼키지 않고 그대로 전파
- 확인 방법: `xcodebuild ... -only-testing:KurlyProjectTests test` → TEST SUCCEEDED

## 결과

- 커밋:
