# 02. API Client와 에러 매핑 (Issue #1, PR -)

## 목표

GitHub 검색 API를 호출하고, HTTP 상태 코드와 네트워크 실패를 `SearchError`로 바꾼다.
실제 서버 없이 실패 상황을 테스트할 수 있게 만든다.

## 프롬프트

> Presentation 폴더 및 swift 파일 이동해주고
> API Clitent까지 진행하고 커밋할거야

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

## 내가 판단·수정한 것

| AI 제안 | 문제 | 수정 | 이유 |
|---|---|---|---|
|  |  |  | (내가 작성) |

## 검증

- 테스트: 전체 16개 통과 (DTO 6, API Client 8, 템플릿 기본 2)
  - 쿼리 생성: 키워드·페이지가 담기는지, 공백 있는 키워드 처리
  - 성공: 200이면 DTO 반환
  - 실패: 연결 실패 / 403 / 429 / 형태 불일치 / 그 외 상태 코드(422)
- 확인 방법: `xcodebuild ... -only-testing:KurlyProjectTests test` → TEST SUCCEEDED

## 결과

- 커밋:
