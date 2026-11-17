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

    var body: some View {
        WebViewRepresentable(url: repository.htmlURL, isLoading: $isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
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

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
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

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        /// iOS 18 이하에서 해제 시 크래시를 막는다 (CLAUDE.md "알려진 함정" 참고)
        nonisolated deinit {}

        // 첫 로드뿐 아니라 페이지 안의 링크로 이동할 때도 표시하려고 시작 시점에 켠다
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        // 실패 화면은 따로 두지 않는다. 표시만 끄고 WebKit이 보여주는 화면을 그대로 둔다
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}
