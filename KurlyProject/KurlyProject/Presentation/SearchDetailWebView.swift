//
//  SearchDetailWebView.swift
//  KurlyProject
//

import SwiftUI
import WebKit

/// 선택한 저장소의 GitHub 페이지.
///
/// 이름을 `WebView`로 하지 않은 이유: iOS 26 SDK의 WebKit에 같은 이름의 SwiftUI 타입이 있어
/// `import WebKit`과 함께 쓰면 이름이 충돌한다.
struct SearchDetailWebView: View {

    let repository: GitHubRepository

    @State private var isLoading = false
    @State private var loadFailed = false

    /// 바꾸면 `.id`가 달라져 WebView를 새로 만든다. 다시 시도할 때 처음부터 다시 로드하려고 쓴다
    @State private var attempt = 0

    var body: some View {
        Group {
            if loadFailed {
                ContentUnavailableView {
                    Label("페이지를 불러오지 못했습니다", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("연결 상태를 확인하고 다시 시도해 주세요.")
                } actions: {
                    Button("다시 시도") {
                        loadFailed = false
                        attempt += 1
                    }
                }
            } else {
                WebViewRepresentable(url: repository.htmlURL, isLoading: $isLoading, loadFailed: $loadFailed)
                    .id(attempt)
                    .overlay {
                        if isLoading {
                            ProgressView()
                        }
                    }
            }
        }
        .navigationTitle(repository.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 최소 지원 iOS 17이라 SwiftUI 네이티브 `WebView`(iOS 26+)를 쓸 수 없어 `WKWebView`를 감싼다
private struct WebViewRepresentable: UIViewRepresentable {

    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadFailed: $loadFailed)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    // url이 바뀌는 경우가 없어 갱신할 것이 없다. 화면마다 새 WebView를 만든다
    func updateUIView(_ webView: WKWebView, context: Context) {}

    /// WebKit의 로딩 시작·끝 알림을 SwiftUI 상태로 옮긴다
    final class Coordinator: NSObject, WKNavigationDelegate {

        @Binding private var isLoading: Bool
        @Binding private var loadFailed: Bool

        /// 저장소 페이지를 한 번이라도 띄웠는지.
        /// 그 뒤 페이지 안의 링크 이동이 실패했을 때 보고 있던 페이지를 에러 화면으로 덮지 않으려고 둔다
        private var hasLoadedOnce = false

        init(isLoading: Binding<Bool>, loadFailed: Binding<Bool>) {
            _isLoading = isLoading
            _loadFailed = loadFailed
        }

        /// iOS 18 이하에서 해제 시 크래시를 막는다 (CLAUDE.md "알려진 함정" 참고)
        nonisolated deinit {}

        // 첫 로드뿐 아니라 페이지 안의 링크로 이동할 때도 표시하려고 시작 시점에 켠다
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            hasLoadedOnce = true
        }

        // 페이지가 이미 보이기 시작한 뒤의 실패다. 보이는 내용을 그대로 두고 표시만 끈다
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        // 서버에 닿기 전의 실패(연결 없음 등). 아직 보여줄 페이지가 없으면 에러 화면으로 바꾼다
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // 링크를 연달아 누르면 앞선 이동이 취소되며 여기로 온다. 새 이동이 이어지므로 실패가 아니다
            if (error as NSError).code == NSURLErrorCancelled { return }

            isLoading = false
            if !hasLoadedOnce {
                loadFailed = true
            }
        }
    }
}
