# 01. DTO와 디코딩 (Issue #1, PR -)

## 목표

GitHub Search API 응답을 받는 DTO를 정의하고, Domain Entity로 변환한다.
실제 API 응답을 고정 데이터로 두고 디코딩이 되는지 테스트로 고정한다.

## 프롬프트

> 이어서 진행

> 실제 API 응답 저장

> a로 진행하자

## AI 응답 요약

- 디코딩 테스트용 JSON을 "실제 응답 저장" vs "직접 작성" 두 가지로 제시
- 실제 API를 호출해 응답을 받고, 쓰는 필드만 남겨 항목 3개로 줄인 고정 데이터 생성
  - 이 과정에서 `per_page` 미지정 시 30개가 온다는 것을 실제로 확인
- `SearchResultDTO` / `RepositoryDTO` / `OwnerDTO` 정의 + `toDomain()` 변환
- **첫 구현의 문제**: URL 필드를 `String`으로 받고 `URL(string:)`이 `nil`이면 항목을 버리도록 작성.
  `html_url`은 버리고 `avatar_url`은 `nil`로 두는 비대칭 설계를 제안
- 테스트 7개 중 2개 실패 → 가정이 틀렸음이 드러남
  - 최신 Foundation의 `URL(string:)`은 공백을 자동 인코딩하고(`"https://github.com/a b"` → `.../a%20b`),
    scheme 없는 문자열도 상대 URL로 받아들인다(`"not a url"` → `not%20a%20url`)
  - `nil`이 되는 입력은 사실상 빈 문자열뿐 → 작성한 `guard`가 거의 동작하지 않는 코드였음
- 수정안 두 가지를 제시
  - A. 검증 제거: `URL` 타입으로 직접 디코딩하고, 어기면 디코딩 실패로 둔다
  - B. 검증 강화: `scheme`과 `host`까지 확인한다
- A를 권장 (원칙 2의 "일어날 수 없는 상황을 위한 에러 처리를 넣지 마라")

## 내가 판단·수정한 것

| AI 제안 | 문제 | 수정 | 이유 |
|---|---|---|---|
| URL을 `String`으로 받고 `URL(string:)` 실패 시 항목을 버림 | `URL(string:)`이 거의 모든 문자열을 받아들여 검증이 실질적으로 동작하지 않음. 검증하지 않은 가정으로 코드를 씀 | A안: `URL` 타입으로 직접 디코딩, `compactMap`과 옵셔널 제거 |  |
| `ownerAvatarURL`만 옵셔널로 두는 비대칭 설계 | 위 가정이 무너지면서 비대칭의 근거도 사라짐 | 옵셔널 제거 |  |

## 검증

- 테스트: `SearchResultDTOTests` 6개 (템플릿 기본 2개 포함 총 8개) 전부 통과
  - 실제 응답 디코딩 / Entity 변환 / 항목 순서 보존
  - `total_count` 키 누락 시 실패
  - `html_url` 키 누락 시 실패
  - `html_url`이 빈 문자열이면 실패
- 확인 방법
  - `xcodebuild ... -only-testing:KurlyProjectTests test` → TEST SUCCEEDED
  - `URL(string:)` 동작은 별도 스크립트로 직접 출력해 확인

## 결과

- 커밋:
