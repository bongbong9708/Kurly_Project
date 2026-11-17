# 09. 저장소 선택 시 WebView 이동 (Issue #11, PR #25)

## 목표

검색 결과에서 저장소를 선택하면 해당 저장소의 GitHub 페이지를 WebView로 연다.

## 프롬프트

> 머지하고 #11

> A1, B1,C2
>
> B1과 C2는 실제 개발된 ui 비교해서 봐야될듯

> 비교안도 보여주고
> 지금 웹뷰 에러처리 화면은 따로 없는것 같은데 같이 작업하자 #12

> #11은 B1, C2로 그대로 진행하자
> ㄴ그리고 리스트 이름이 SearchView인데 연관성있게 SearchDetailWebView로 이름 변경바람.
>
> #12는 결정사항이 많으니 기존꺼커밋하고 진행해야겠다

## AI 응답 요약

- 가정 명시: 타입 이름을 `WebView`로 하지 않고 `RepositoryWebView`로 둔다 (iOS 26 SDK의 SwiftUI `WebView`와 이름 충돌 가능)
- 설계 선택지 3개 제시
  - A. 이동 방식: `NavigationLink(value:)` + `navigationDestination` (A1, 추천) vs `NavigationLink(destination:)` (A2)
  - B. 타이틀: 저장소 이름 표시 + Entity `Hashable` (B1) vs `htmlURL`만 넘기고 타이틀 없음 (B2)
  - C. 로딩 표시: 없음 (C1) vs `WKNavigationDelegate`로 `ProgressView` (C2, 요구사항 밖)
- 웹 페이지 로드 실패는 별도 처리하지 않는다고 명시
- 구현
  - `GitHubRepository`: `Equatable` → `Hashable`
  - `SearchView`: 결과 행을 `NavigationLink(value:)`로 감싸고, `.navigationDestination`은 List 바깥(`content`)에 붙임
  - `RepositoryWebView`: `WKWebView`를 `UIViewRepresentable`로 감싸고 Coordinator가 로딩 시작·끝을 `isLoading` 바인딩으로 전달
    - 페이지 안의 링크 이동에도 표시되도록 `didStartProvisionalNavigation`에서 켬
    - Coordinator도 클래스라 "알려진 함정"에 따라 `nonisolated deinit {}`
- 시뮬레이터 확인 중 다른 시뮬레이터(iPhone 16, iOS 18.2)에 탭 한 번이 잘못 들어감 (iPhone 16 Pro가 꺼진 상태라 기본 기기로 넘어감)
- 처음 보고에서는 로딩 표시를 스크린샷으로 잡지 못해 "미확인"으로 남김
- 비교안 요청에 대해
  - 시뮬레이터 화면을 녹화하고 AVFoundation 스크립트로 0.2초 간격 프레임을 뽑아 로딩 중 화면을 캡처
  - 첫 녹화는 탭이 최근 검색어 행에 들어가 검색 로딩이 찍힘 → 다시 녹화
  - B2·C1은 타이틀과 `ProgressView`를 임시로 지운 빌드로 녹화한 뒤 원래 코드로 복구
  - 4장 비교 이미지 제공: 로드 후에는 페이지 상단에 저장소 이름이 보여 타이틀과 겹치고, 차이는 로딩 중(약 1.2초)에 드러남
- WebView 에러 처리를 #12와 함께 하자는 요청에 설계 선택지 A~G를 정리해 제시 (결정은 #12에서)
- 타입 이름을 `SearchDetailWebView`로 변경 (파일명 포함)

## 내가 판단·수정한 것

| AI 제안 | 문제 | 수정 | 이유 |
|---|---|---|---|
| 타입 이름 `RepositoryWebView` | 사용자 지적: 목록 화면 `SearchView`와 이름의 연관성이 없음 | `SearchDetailWebView`로 변경 | (내가 작성) |
| B(타이틀)·C(로딩 표시) 선택지를 글로만 설명 | 사용자 지적: 실제 화면을 비교해 봐야 고를 수 있음 | 시뮬레이터에서 화면을 만들어 비교한 뒤 B1·C2 선택 | (내가 작성) |

## 검증

- 테스트: `-only-testing:KurlyProjectTests` 전체 통과 (iOS 18.6). 화면 전환만 바뀌어 새 테스트 없음
- 확인 방법: iPhone 16 Pro (iOS 18.6) 시뮬레이터
  - 결과 행에 `>` 표시, `swift` (swiftlang) 탭 → 타이틀 `swift`, 뒤로가기 `Search`, 저장소 페이지 로드
  - 로딩 표시(`ProgressView`): 화면 녹화 프레임에서 확인 (TheAlgorithms/Kotlin, 약 1.2초 표시)
  - 이름 변경 후 단위 테스트 재실행 통과

## 결과

- 커밋: `3fc7c31` 저장소 선택 시 WebView 이동
- PR: #25
