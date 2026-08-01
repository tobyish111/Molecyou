import SwiftUI
import WebKit

struct MolecularViewerWebView: UIViewRepresentable {
    let structureURL: URL?
    let structureData: String
    let includeDataFallback: Bool
    let proteinName: String
    let accession: String
    let command: MolecularViewerCommand?
    let onEvent: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController.add(context.coordinator, name: "molecularYou")
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        do {
            let runtimeDirectory = try MolecularViewerRuntime.prepare()
            context.coordinator.runtimeDirectory = runtimeDirectory
            let htmlURL = runtimeDirectory.appending(path: "viewer.html")
            webView.loadFileURL(htmlURL, allowingReadAccessTo: runtimeDirectory)
        } catch {
            Task { @MainActor in onEvent("failed: \(error.localizedDescription)") }
            webView.loadHTMLString(Self.fallbackHTML(message: error.localizedDescription), baseURL: nil)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.loadedStructureURL != structureURL {
            context.coordinator.loadedStructureURL = structureURL
            guard let structureURL, let runtimeDirectory = context.coordinator.runtimeDirectory else { return }

            do {
                let runtimeStructureURL = try MolecularViewerRuntime.copyStructure(structureURL, accession: accession, to: runtimeDirectory)
                var payload = [
                    "name": proteinName,
                    "accession": accession,
                    "url": runtimeStructureURL.lastPathComponent,
                    "format": "mmcif"
                ]
                if includeDataFallback {
                    payload["dataBase64"] = Data(structureData.utf8).base64EncodedString()
                }
                if let json = try? String(data: JSONSerialization.data(withJSONObject: payload), encoding: .utf8) {
                    let script = """
                    window.MolecularYouLoadQueue = window.MolecularYouLoadQueue || [];
                    if (window.MolecularYou && window.MolecularYou.loadStructure) {
                      window.MolecularYou.loadStructure(\(json));
                    } else {
                      window.MolecularYouLoadQueue.push(\(json));
                    }
                    """
                    context.coordinator.enqueueOrEvaluate(script, in: webView)
                }
            } catch {
                Task { @MainActor in onEvent("failed: \(error.localizedDescription)") }
            }
        }

        if context.coordinator.lastCommand != command, let command {
            context.coordinator.lastCommand = command
            let payload = Self.javascriptPayload(for: command)
            let script = """
            window.MolecularYouCommandQueue = window.MolecularYouCommandQueue || [];
            if (window.MolecularYou && window.MolecularYou.command) {
              window.MolecularYou.command(\(payload));
            } else {
              window.MolecularYouCommandQueue.push(\(payload));
            }
            """
            context.coordinator.enqueueOrEvaluate(script, in: webView)
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
        case .focusRegion(let chainID, let startSequenceNumber, let endSequenceNumber, let label):
            dictionary = ["type": "focusRegion", "chainID": chainID, "startSequenceNumber": startSequenceNumber, "endSequenceNumber": endSequenceNumber, "label": label]
        case .toggleLabels(let enabled): dictionary = ["type": "toggleLabels", "value": enabled]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary), let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var runtimeDirectory: URL?
        var loadedStructureURL: URL?
        var lastCommand: MolecularViewerCommand?
        private var hasLoadedViewerPage = false
        private var pendingScripts: [String] = []
        let onEvent: @MainActor (String) -> Void

        init(onEvent: @escaping @MainActor (String) -> Void) {
            self.onEvent = onEvent
        }

        func enqueueOrEvaluate(_ script: String, in webView: WKWebView) {
            guard hasLoadedViewerPage else {
                pendingScripts.append(script)
                Task { @MainActor in onEvent("Preparing viewer resources") }
                return
            }

            evaluate(script, in: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            hasLoadedViewerPage = true
            let scripts = pendingScripts
            pendingScripts.removeAll()
            for script in scripts {
                evaluate(script, in: webView)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
            Task { @MainActor in onEvent("failed: \(error.localizedDescription)") }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
            Task { @MainActor in onEvent("failed: \(error.localizedDescription)") }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let body: String
            if let dictionary = message.body as? [String: Any], let type = dictionary["type"] as? String {
                if let eventMessage = dictionary["message"] as? String {
                    body = "\(type): \(eventMessage)"
                } else if let name = dictionary["name"] as? String, !name.isEmpty {
                    body = "\(type): \(name)"
                } else {
                    body = type
                }
            } else {
                body = String(describing: message.body)
            }
            Task { @MainActor in onEvent(body) }
        }

        private func evaluate(_ script: String, in webView: WKWebView) {
            webView.evaluateJavaScript(script) { [onEvent] _, error in
                if let error {
                    Task { @MainActor in onEvent("failed: \(error.localizedDescription)") }
                }
            }
        }
    }

    private static func fallbackHTML(message: String) -> String {
        """
        <!doctype html><html><body style='margin:0;background:#020617;color:white;font-family:-apple-system;display:grid;place-items:center'><div>Mol* viewer unavailable<br><small>\(message)</small></div></body></html>
        """
    }
}

private enum MolecularViewerRuntime {
    static func prepare() throws -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "MolStarRuntime", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for resource in requiredResources {
            guard let sourceURL = bundledResourceURL(named: resource.name, extension: resource.extension) else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(resource.name).\(resource.extension)"])
            }
            let destinationURL = directory.appending(path: "\(resource.name).\(resource.extension)")
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }

        return directory
    }

    static func copyStructure(_ sourceURL: URL, accession: String, to directory: URL) throws -> URL {
        let safeAccession = accession.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        let destinationURL = directory.appending(path: "\(safeAccession).cif")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private static let requiredResources: [(name: String, extension: String)] = [
        ("viewer", "html"),
        ("viewer", "css"),
        ("viewer", "js"),
        ("molstar", "css"),
        ("molstar", "js")
    ]

    private static func bundledResourceURL(named name: String, extension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources/MolStar")
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "MolStar")
            ?? Bundle.main.url(forResource: name, withExtension: ext)
    }
}
