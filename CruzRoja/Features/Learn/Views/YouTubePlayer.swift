import SwiftUI
import WebKit

@MainActor
final class YouTubePlayerController: LessonVideoPlayback {
    weak var webView: WKWebView?

    func pause() {
        webView?.pauseAllMediaPlayback(completionHandler: nil)
    }

    func stop() {
        webView?.pauseAllMediaPlayback(completionHandler: nil)
        webView?.stopLoading()
        webView?.load(URLRequest(url: URL(string: "about:blank")!))
        webView = nil
    }

    // WebKit exposes a state query, but no callback for changes in playback.
    func monitorPlayback(onPlayback: @escaping @MainActor () -> Void) async {
        var wasPlaying = false
        while !Task.isCancelled {
            if let webView {
                let state = await withCheckedContinuation { continuation in
                    webView.requestMediaPlaybackState { continuation.resume(returning: $0) }
                }
                guard !Task.isCancelled else { return }
                let isPlaying = state == .playing
                if isPlaying && !wasPlaying { onPlayback() }
                wasPlaying = isPlaying
            }
            try? await Task.sleep(for: .milliseconds(400))
        }
    }
}

/// Loads YouTube's native embed page; its own controls handle playback.
struct YouTubePlayer: UIViewRepresentable {
    let video: YouTubeVideo
    let controller: YouTubePlayerController
    let autoplay: Bool
    let onLoad: @MainActor () -> Void
    let onFailure: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoad: onLoad, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = autoplay ? [] : .all
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        controller.webView = webView

        // YouTube requires the installed app's bundle ID as the HTTPS referrer.
        guard let bundleID = Bundle.main.bundleIdentifier,
              let origin = URL(string: "https://\(bundleID.lowercased())") else {
            onFailure()
            return webView
        }
        var embed = URLComponents(string: "https://www.youtube.com/embed/\(video.id)")!
        embed.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "autoplay", value: autoplay ? "1" : "0"),
            URLQueryItem(name: "controls", value: "1"),
            URLQueryItem(name: "hl", value: "es"),
            URLQueryItem(name: "cc_lang_pref", value: "es"),
            URLQueryItem(name: "origin", value: origin.absoluteString),
        ]
        var request = URLRequest(url: embed.url!)
        request.setValue(origin.absoluteString, forHTTPHeaderField: "Referer")
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.isActive = false
        uiView.navigationDelegate = nil
        uiView.pauseAllMediaPlayback(completionHandler: nil)
        uiView.stopLoading()
        uiView.load(URLRequest(url: URL(string: "about:blank")!))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onLoad: @MainActor () -> Void
        let onFailure: @MainActor () -> Void
        var isActive = true

        init(onLoad: @escaping @MainActor () -> Void, onFailure: @escaping @MainActor () -> Void) {
            self.onLoad = onLoad
            self.onFailure = onFailure
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard isActive else { return }
            onLoad()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.isForMainFrame,
               let response = navigationResponse.response as? HTTPURLResponse,
               !(200..<400).contains(response.statusCode) {
                fail()
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail() }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail() }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fail() }

        private func fail() {
            guard isActive else { return }
            onFailure()
        }
    }
}
