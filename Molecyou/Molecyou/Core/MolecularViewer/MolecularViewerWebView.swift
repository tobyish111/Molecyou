import SwiftUI
import WebKit

struct MolecularViewerWebView: UIViewRepresentable {
    let structureURL: URL?
    let structureData: String?
    let proteinName: String
    let accession: String
    let command: MolecularViewerCommand?
    let onEvent: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "molecularYou")
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        if let htmlURL = Bundle.main.url(forResource: "viewer", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            webView.loadHTMLString(Self.fallbackHTML, baseURL: nil)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.loadedStructureURL != structureURL {
            context.coordinator.loadedStructureURL = structureURL
            let payload = [
                "name": proteinName,
                "accession": accession,
                "url": structureURL?.lastPathComponent ?? "",
                "format": "mmcif",
                "dataBase64": structureData.map { Data($0.utf8).base64EncodedString() } ?? ""
            ]
            if let json = try? String(data: JSONSerialization.data(withJSONObject: payload), encoding: .utf8) {
                webView.evaluateJavaScript("window.MolecularYou && window.MolecularYou.loadStructure(\(json));")
            }
        }

        if context.coordinator.lastCommand != command, let command {
            context.coordinator.lastCommand = command
            webView.evaluateJavaScript("window.MolecularYou && window.MolecularYou.command(\(Self.javascriptPayload(for: command)));")
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "molecularYou")
        uiView.stopLoading()
    }

    private static func javascriptPayload(for command: MolecularViewerCommand) -> String {
        let dictionary: [String: Any]
        switch command {
        case .resetCamera: dictionary = ["type": "resetCamera"]
        case .centerStructure: dictionary = ["type": "centerStructure"]
        case .setRepresentation(let representation): dictionary = ["type": "setRepresentation", "value": representation.rawValue]
        case .setColorMode(let mode): dictionary = ["type": "setColorMode", "value": mode.rawValue]
        case .focusResidue(let chainID, let sequenceNumber): dictionary = ["type": "focusResidue", "chainID": chainID, "sequenceNumber": sequenceNumber]
        case .toggleLabels(let enabled): dictionary = ["type": "toggleLabels", "value": enabled]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary), let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var loadedStructureURL: URL?
        var lastCommand: MolecularViewerCommand?
        let onEvent: @MainActor (String) -> Void

        init(onEvent: @escaping @MainActor (String) -> Void) {
            self.onEvent = onEvent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let body = String(describing: message.body)
            Task { @MainActor in onEvent(body) }
        }
    }

    private static let fallbackHTML = """
    <!doctype html><html><body style='margin:0;background:#020617;color:white;font-family:-apple-system'><div id='app'>Molecular viewer unavailable</div></body></html>
    """
}
