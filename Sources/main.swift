// Atelier sticker holo — app macOS
// Une fenêtre AppKit qui affiche l'atelier (Resources/atelier.html) dans un WKWebView,
// avec un pont JavaScript pour copier et enregistrer le sticker en PNG et garder les créations.

import AppKit
import WebKit
import UniformTypeIdentifiers

final class AtelierApp: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private let defaults = UserDefaults.standard
    private let appName = "Atelier sticker holo"

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()

        // État et stickers gardés, rendus à la page avant son chargement
        let controller = WKUserContentController()
        controller.add(self, name: "atelier")
        let payload: [String: Any] = [
            "app": "mac",
            "state": defaults.string(forKey: "state") ?? NSNull(),
            "saved": defaults.string(forKey: "saved") ?? NSNull()
        ]
        let json = (try? JSONSerialization.data(withJSONObject: payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        controller.addUserScript(WKUserScript(source: "window.__atelierNative = \(json);", injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        if #available(macOS 13.3, *) { webView.isInspectable = true }

        let ground = NSColor(srgbRed: 0.051, green: 0.141, blue: 0.118, alpha: 1)
        if #available(macOS 12.0, *) { webView.underPageBackgroundColor = ground }

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1360, height: 880),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = appName
        window.titlebarAppearsTransparent = true
        window.backgroundColor = ground
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 960, height: 640)
        window.contentView = webView
        window.center()
        _ = window.setFrameAutosaveName("AtelierStickerWindow")
        window.makeKeyAndOrderFront(nil)

        if let url = Bundle.main.url(forResource: "atelier", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: Pont JavaScript → Swift

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "copy":
            guard let data = pngData(body["png"]) else { reply("copy", false); return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            if let image = NSImage(data: data) { pasteboard.writeObjects([image]) }
            pasteboard.setData(data, forType: .png)
            reply("copy", true)
        case "save":
            guard let data = pngData(body["png"]) else { reply("save", false); return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.png]
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = (body["name"] as? String) ?? "sticker.png"
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }
                do { try data.write(to: url); self.reply("save", true) } catch { self.reply("save", false) }
            }
        case "store":
            if let key = body["key"] as? String, ["state", "saved"].contains(key), let value = body["value"] as? String {
                defaults.set(value, forKey: key)
            }
        case "log":
            if let text = body["msg"] as? String { log(text) }
        default:
            break
        }
    }

    private func pngData(_ value: Any?) -> Data? {
        guard let string = value as? String, let comma = string.firstIndex(of: ",") else { return nil }
        return Data(base64Encoded: String(string[string.index(after: comma)...]))
    }

    private func reply(_ kind: String, _ ok: Bool) {
        webView.evaluateJavaScript("window.atelierNativeReply && window.atelierNativeReply('\(kind)', \(ok))", completionHandler: nil)
    }

    private func run(_ command: String) {
        webView.evaluateJavaScript("window.atelierCommand && window.atelierCommand('\(command)')", completionHandler: nil)
    }

    private func log(_ text: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/AtelierStickerHolo.log")
        let line = Data("\(ISO8601DateFormatter().string(from: Date())) \(text)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }

    // MARK: Liens externes → navigateur par défaut

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
        return nil
    }

    // MARK: Menus

    @objc func copySticker(_ sender: Any?) { run("copy") }
    @objc func savePNG(_ sender: Any?) { run("save") }
    @objc func keepSticker(_ sender: Any?) { run("keep") }
    @objc func shuffle(_ sender: Any?) { run("shuffle") }
    @objc func resetSticker(_ sender: Any?) { run("reset") }
    @objc func reloadPage(_ sender: Any?) { webView.reload() }

    private func buildMenu() {
        func item(_ title: String, _ action: Selector?, _ key: String = "", _ mods: NSEvent.ModifierFlags = [.command], target: AnyObject? = nil) -> NSMenuItem {
            let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
            it.keyEquivalentModifierMask = mods
            it.target = target
            return it
        }
        let appMenu = NSMenu()
        appMenu.addItem(item("À propos de \(appName)", #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Masquer \(appName)", #selector(NSApplication.hide(_:)), "h"))
        appMenu.addItem(item("Masquer les autres", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        appMenu.addItem(item("Tout afficher", #selector(NSApplication.unhideAllApplications(_:))))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Quitter \(appName)", #selector(NSApplication.terminate(_:)), "q"))

        let stickerMenu = NSMenu(title: "Sticker")
        stickerMenu.addItem(item("Décoller et copier", #selector(copySticker(_:)), "c", [.command, .shift], target: self))
        stickerMenu.addItem(item("Enregistrer en PNG…", #selector(savePNG(_:)), "s", target: self))
        stickerMenu.addItem(item("Garder dans Mes stickers", #selector(keepSticker(_:)), "k", target: self))
        stickerMenu.addItem(.separator())
        stickerMenu.addItem(item("Mélanger", #selector(shuffle(_:)), "r", target: self))
        stickerMenu.addItem(item("Réinitialiser", #selector(resetSticker(_:)), "r", [.command, .shift], target: self))

        let editMenu = NSMenu(title: "Édition")
        editMenu.addItem(item("Annuler", Selector(("undo:")), "z"))
        editMenu.addItem(item("Rétablir", Selector(("redo:")), "z", [.command, .shift]))
        editMenu.addItem(.separator())
        editMenu.addItem(item("Couper", #selector(NSText.cut(_:)), "x"))
        editMenu.addItem(item("Copier", #selector(NSText.copy(_:)), "c"))
        editMenu.addItem(item("Coller", #selector(NSText.paste(_:)), "v"))
        editMenu.addItem(item("Tout sélectionner", #selector(NSText.selectAll(_:)), "a"))

        let viewMenu = NSMenu(title: "Présentation")
        viewMenu.addItem(item("Recharger l’atelier", #selector(reloadPage(_:)), "r", [.command, .option], target: self))
        viewMenu.addItem(item("Plein écran", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]))

        let windowMenu = NSMenu(title: "Fenêtre")
        windowMenu.addItem(item("Réduire", #selector(NSWindow.performMiniaturize(_:)), "m"))
        windowMenu.addItem(item("Zoom", #selector(NSWindow.performZoom(_:))))

        let main = NSMenu()
        for (title, menu) in [(appName, appMenu), ("Sticker", stickerMenu), ("Édition", editMenu), ("Présentation", viewMenu), ("Fenêtre", windowMenu)] {
            let top = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            top.submenu = menu
            main.addItem(top)
        }
        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }
}

let app = NSApplication.shared
let delegate = AtelierApp()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
