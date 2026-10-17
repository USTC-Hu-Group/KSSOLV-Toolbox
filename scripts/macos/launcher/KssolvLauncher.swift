import AppKit
import WebKit
import Darwin
import CryptoKit

// Borderless NSWindow instances cannot become key by default. WebKit needs a
// key window and mouse-moved delivery for hover/cursor feedback and first-click
// interaction with the startup card's cancel button.
final class StartupCardWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class StartupCancelButton: NSButton {
    private var hoverArea: NSTrackingArea?
    private var hovered = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        if let hoverArea = hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
        super.updateTrackingAreas()
        if let window = window {
            hovered = bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
            updateBackground()
        }
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
    override func mouseEntered(with event: NSEvent) { hovered = true; updateBackground() }
    override func mouseExited(with event: NSEvent) { hovered = false; updateBackground() }
    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = NSColor(srgbRed: 0.56, green: 0.13, blue: 0.17, alpha: 1).cgColor
        super.mouseDown(with: event)
        updateBackground()
    }
    private func updateBackground() {
        layer?.backgroundColor = (hovered ? NSColor(srgbRed: 0.71, green: 0.17, blue: 0.22, alpha: 1) : .clear).cgColor
    }
}

// The outer .app loads no MATLAB libraries. The original Compiler app is retained
// in Helpers, while its runner and a relative app link live in Resources/Runtime.
final class StartupHost: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, NSWindowDelegate {
    private let resources: URL
    private let config: [String: Any]
    private let arguments: [String]
    private let nonce: String
    private let channel: URL
    private let log: URL
    private let locale: String
    private var window: NSWindow!
    private var web: WKWebView!
    private var cardCanvas: NSView?
    private var fittingCard = false
    private var timer: Timer?
    private var child: pid_t = 0
    private var processGroup: pid_t = 0
    private var childExited = false
    private var acknowledged = false
    private var finished = false
    private var running = false
    private var dockTransferred = false
    private var terminating = false
    private var cefPID: pid_t = 0
    private var bridgeWaitingSince: Date?
    private var bridgeRegistration: URL?
    private var runtimeMonitor: DispatchSourceProcess?
    private var windowProcessMonitor: DispatchSourceProcess?
    private var started = Date()
    private var presentationChecking = false
    private var presentationPainted = false
    private var windowBundleIdentifier: String { config["windowBundleIdentifier"] as? String ?? "org.cef.MATLABWindow" }

    init(resources: URL, config: [String: Any], arguments: [String]) throws {
        guard let version = config["version"] as? String, !version.isEmpty else {
            throw hostError("The application version is missing from startup configuration.")
        }
        let token = UUID().uuidString
        nonce = token
        self.resources = resources
        self.config = config
        self.arguments = arguments
        locale = startupLocale(environment: ProcessInfo.processInfo.environment)
        let signalFolder = FileManager.default.temporaryDirectory.appendingPathComponent("kssolv-startup-" + token, isDirectory: true)
        channel = signalFolder
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/KSSOLV Toolbox", isDirectory: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        log = logs.appendingPathComponent("startup.log")
        try FileManager.default.createDirectory(at: signalFolder, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = WKUserContentController()
        controller.add(self, name: "cardReady")
        controller.add(self, name: "cancel")
        record("launch-requested locale=" + locale)
        let language = locale == "zh_CN" ? "zh" : "en"
        guard let bytes = try? JSONSerialization.data(withJSONObject: ["language": language, "version": config["version"] as? String ?? "", "nativeCancel": true]),
            let metadata = String(data: bytes, encoding: .utf8) else { fail("Unable to read startup metadata."); return }
        controller.addUserScript(WKUserScript(source: "window.kssolvStartup=\(metadata);", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 494), configuration: configuration)
        web.navigationDelegate = self
        window = StartupCardWindow(contentRect: web.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        window.acceptsMouseMovedEvents = true
        window.title = "KSSOLV Toolbox"
        window.isReleasedWhenClosed = false
        // MATLAB is a separate application and can become active before it has
        // a visible window. Keep its startup card out of Stage Manager's strip.
        window.level = .floating
        window.collectionBehavior = [.fullScreenAuxiliary]
        if #available(macOS 13.0, *) {
            window.collectionBehavior.insert(.canJoinAllApplications)
        }
        window.delegate = self
        let canvas = NSView(frame: web.bounds)
        // Keep WebKit's logical viewport fixed; AppKit scales this entire
        // canvas, including the native cancel button, on small work areas.
        canvas.autoresizesSubviews = false
        canvas.addSubview(web)
        let cancel = StartupCancelButton(frame: NSRect(x: 756, y: 458, width: 44, height: 36))
        cancel.autoresizingMask = [.minXMargin, .minYMargin]
        cancel.title = "×"
        cancel.font = .systemFont(ofSize: 22)
        cancel.contentTintColor = .white
        cancel.isBordered = false
        cancel.wantsLayer = true
        cancel.toolTip = locale == "zh_CN" ? "取消启动" : "Cancel startup"
        cancel.setAccessibilityLabel(cancel.toolTip)
        cancel.target = self
        cancel.action = #selector(cancelStartup(_:))
        canvas.addSubview(cancel)
        let content = NSView(frame: web.bounds)
        content.addSubview(canvas)
        window.contentView = content
        cardCanvas = canvas
        fitStartupCard()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let folder = resources.appendingPathComponent("startup", isDirectory: true)
        web.loadFileURL(folder.appendingPathComponent("index.html"), allowingReadAccessTo: folder)
        started = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.poll() }
    }

    @objc private func cancelStartup(_ sender: Any?) {
        fail("Application startup was cancelled.", alert: false)
    }

    private func fitStartupCard() {
        guard !finished, !running, !fittingCard, let window = window,
            let canvas = cardCanvas, let screen = window.screen ?? NSScreen.main else { return }
        #if KSSOLV_TEST_SMALL_DISPLAY
        // Native UI fixture only; normal builds contain no display override.
        let visibleFrame = NSRect(x: screen.visibleFrame.minX, y: screen.visibleFrame.minY, width: 640, height: 400)
        #else
        let visibleFrame = screen.visibleFrame
        #endif
        let available = visibleFrame.insetBy(dx: 16, dy: 16)
        guard available.width > 0, available.height > 0 else { return }
        fittingCard = true
        defer { fittingCard = false }
        let scale = min(1, available.width / 800, available.height / 494)
        let size = NSSize(width: 800 * scale, height: 494 * scale)
        window.setContentSize(size)
        canvas.frame = NSRect(origin: .zero, size: size)
        canvas.bounds = NSRect(x: 0, y: 0, width: 800, height: 494)
        window.setFrameOrigin(NSPoint(x: available.midX - size.width / 2, y: available.midY - size.height / 2))
        for case let button as StartupCancelButton in canvas.subviews {
            button.updateTrackingAreas()
            window.invalidateCursorRects(for: button)
        }
        record("card-layout width=\(size.width) height=\(size.height) scale=\(scale)")
    }

    func windowDidChangeScreen(_ notification: Notification) { fitStartupCard() }
    func applicationDidChangeScreenParameters(_ notification: Notification) { fitStartupCard() }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !finished, message.frameInfo.isMainFrame else { return }
        if message.name == "cancel" { fail("Application startup was cancelled.", alert: false); return }
        guard message.name == "cardReady", child == 0 else { return }
        do {
            record("card-painted")
            var environment = ProcessInfo.processInfo.environment
            environment.removeValue(forKey: "KSSOLV_PREWARM_RESULT")
            environment.removeValue(forKey: "KSSOLV_PREWARM_NONCE")
            environment["KSSOLV_HOST_IN_BROWSER"] = "0"
            environment["KSSOLV_LOCALE"] = locale
            environment["KSSOLV_STARTUP_SIGNAL"] = channel.appendingPathComponent("status.json").path
            environment["KSSOLV_STARTUP_NONCE"] = nonce
            environment["KSSOLV_DOCK_BRIDGE"] = "1"
            environment["KSSOLV_STARTUP_COMPLETION"] = log.deletingLastPathComponent().appendingPathComponent("startup-loaded.json").path
            let runtime = try runtimeRoot(config: config, environment: environment)
            let privateWindow = try prepareWindowCache(resources: resources, runtime: runtime)
            child = try spawnRunner(resources: resources, runtime: runtime, arguments: arguments, environment: environment)
            processGroup = child
            let registry = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("KSSOLV Toolbox/dock", isDirectory: true)
            try FileManager.default.createDirectory(at: registry, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            let registration = registry.appendingPathComponent("\(processGroup).json")
            let metadata: [String: Any] = ["pgid": Int(processGroup), "host": Int(getpid()), "nonce": nonce,
                "signal": channel.appendingPathComponent("status.json").path,
                "library": resources.deletingLastPathComponent().appendingPathComponent("Frameworks/KssolvDockBridge.dylib").resolvingSymlinksInPath().path,
                "icon": resources.appendingPathComponent("KssolvBrand.icns").path,
                "executable": Bundle.main.executableURL!.resolvingSymlinksInPath().path,
                "runtimeExecutable": resources.deletingLastPathComponent().appendingPathComponent("Helpers/KSSOLV_Toolbox.app/Contents/MacOS/KSSOLV_Toolbox").resolvingSymlinksInPath().path,
                "sourceWindowExecutable": runtime + "/bin/maca64/MATLABWindow.app/Contents/MacOS/MATLABWindow",
                "windowExecutable": privateWindow.appendingPathComponent("Contents/MacOS/MATLABWindow").path]
            try JSONSerialization.data(withJSONObject: metadata).write(to: registration, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: registration.path)
            bridgeRegistration = registration
            started = Date()
            record("runtime-started pid=\(child)")
        } catch { fail(error.localizedDescription) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let allowed = resources.appendingPathComponent("startup/index.html").standardizedFileURL
        decisionHandler(navigationAction.request.url?.standardizedFileURL == allowed ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error.localizedDescription)
    }

    private func poll() {
        if running {
            var status: Int32 = 0
            if !childExited && waitpid(child, &status, WNOHANG) == child { childExited = true }
            if childExited { finishRunning() }
            return
        }
        guard !finished else { return }
        guard child > 0 else {
            if Date().timeIntervalSince(started) > 15 { fail("The local HTML startup card could not be rendered.") }
            return
        }
        var exitStatus: Int32 = 0
        if !childExited && waitpid(child, &exitStatus, WNOHANG) == child { childExited = true }
        let signal = channel.appendingPathComponent("status.json")
        do {
            let requestPath = URL(fileURLWithPath: signal.path + ".dock-transfer")
            if !dockTransferred, let requestBytes = try? Data(contentsOf: requestPath) {
                guard let request = try JSONSerialization.jsonObject(with: requestBytes) as? [String: Any],
                    request["nonce"] as? String == nonce,
                    let pid = request["pid"] as? Int, pid > 0,
                    getpgid(pid_t(pid)) == processGroup,
                    NSRunningApplication(processIdentifier: pid_t(pid))?.bundleIdentifier == windowBundleIdentifier
                else { throw hostError("Invalid Dock ownership transfer request.") }
                let monitor = DispatchSource.makeProcessSource(identifier: pid_t(pid), eventMask: .exit, queue: .main)
                monitor.setEventHandler { [weak self] in
                    guard let self = self else { return }
                    if self.running { self.record("window-process-finished"); self.finishRunning() }
                    else if !self.finished { self.fail("The Toolbox window process exited during startup.") }
                }
                windowProcessMonitor = monitor
                monitor.resume()
                guard NSApp.setActivationPolicy(.accessory) else { throw hostError("Unable to retire startup Dock ownership.") }
                dockTransferred = true
                record("dock-host-retired")
                let reply = try JSONSerialization.data(withJSONObject: ["nonce": nonce, "pid": pid, "retired": true])
                try reply.write(to: URL(fileURLWithPath: signal.path + ".dock-transfer-ack"), options: .atomic)
            }
            if childExited { throw hostError("Application exited before its interface was ready (wait status \(exitStatus)).") }
            if Date().timeIntervalSince(started) > 900 { throw hostError("Application startup exceeded 15 minutes. See " + log.path) }
            if FileManager.default.fileExists(atPath: signal.path) {
                // The backend publishes by atomic rename. A transient missing file is retried.
                let bytes: Data
                do { bytes = try Data(contentsOf: signal) }
                catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError { return }
                guard let data = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                    data["nonce"] as? String == nonce, data["protocol"] as? Int == 1,
                    let status = data["status"] as? String else { throw hostError("Invalid application startup signal.") }
                switch status {
                case "shell-ready":
                    if !acknowledged {
                        // Do not reveal a window unless this launch's CEF has
                        // installed its bridge before any foreground promotion.
                        if cefPID == 0 {
                            let bridgeFile = URL(fileURLWithPath: signal.path + ".bridge")
                            guard let bytes = try? Data(contentsOf: bridgeFile) else {
                                if bridgeWaitingSince == nil { bridgeWaitingSince = Date() }
                                if Date().timeIntervalSince(bridgeWaitingSince!) > 10 {
                                    throw hostError("The macOS Dock bridge did not become ready. See " + log.path)
                                }
                                return
                            }
                            guard let bridge = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                                bridge["protocol"] as? Int == 1, bridge["nonce"] as? String == nonce,
                                bridge["policy"] as? Int == NSApplication.ActivationPolicy.regular.rawValue,
                                let pid = bridge["pid"] as? Int, pid > 0,
                                bridge["pgid"] as? Int == Int(processGroup), getpgid(pid_t(pid)) == processGroup,
                                NSRunningApplication(processIdentifier: pid_t(pid))?.bundleIdentifier == windowBundleIdentifier
                            else { throw hostError("Invalid macOS Dock bridge startup signal.") }
                            cefPID = pid_t(pid)
                            record("dock-bridge-ready pid=\(cefPID)")
                        }
                        if !presentationPainted {
                            if !presentationChecking {
                                presentationChecking = true
                                web.evaluateJavaScript("window.prepareStartupHandoff() ? JSON.stringify(window.getStartupPresentation()) : null") { [weak self] value, error in
                                    guard let self = self, !self.finished else { return }
                                    self.presentationChecking = false
                                    if let error = error { self.fail(error.localizedDescription); return }
                                    if let snapshot = value as? String {
                                        self.record("presentation " + snapshot)
                                        self.presentationPainted = true
                                    }
                                }
                            }
                            return
                        }
                        record("shell-ready")
                        // CEF owns the Toolbox window in a separate application.
                        // Switch to this launch's CEF app before revealing it so
                        // Stage Manager does not leave it in an inactive set.
                        if let runtimeWindow = NSWorkspace.shared.runningApplications.first(where: {
                            $0.bundleIdentifier == windowBundleIdentifier && getpgid($0.processIdentifier) == processGroup
                        }) {
                            runtimeWindow.activate(options: [.activateIgnoringOtherApps])
                        }
                        let bytes = try JSONSerialization.data(withJSONObject: ["nonce": nonce])
                        try bytes.write(to: URL(fileURLWithPath: signal.path + ".reveal"), options: .atomic)
                        acknowledged = true
                    }
                case "visible":
                    guard acknowledged && !childExited else { throw hostError("The application did not complete the startup handshake.") }
                    record("window-visible")
                    complete()
                    return
                case "failed": throw hostError(data["error"] as? String ?? "Application startup failed.")
                default: throw hostError("Unknown application startup state: " + status)
                }
            }
        } catch { fail(error.localizedDescription) }
    }

    private func complete() {
        finished = true
        running = true
        timer?.invalidate()
        window.orderOut(nil)
        record("card-closed")
        web.configuration.userContentController.removeAllScriptMessageHandlers()
        web.stopLoading()
        window.contentView = nil
        web = nil
        window = nil
        let monitor = DispatchSource.makeProcessSource(identifier: child, eventMask: .exit, queue: .main)
        monitor.setEventHandler { [weak self] in
            guard let self = self else { return }
            var status: Int32 = 0
            _ = waitpid(self.child, &status, WNOHANG)
            self.childExited = true
            self.finishRunning()
        }
        runtimeMonitor = monitor
        monitor.resume()
        sendDockCommand("show")
        // The retained accessory host owns only startup/lifetime cleanup.
        // The regular CEF process now owns the one branded Dock tile and menus.
        let menu = NSMenu()
        let applicationMenu = NSMenu()
        let quit = NSMenuItem(title: locale == "zh_CN" ? "退出 KSSOLV Toolbox" : "Quit KSSOLV Toolbox",
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationMenu.addItem(quit)
        let item = NSMenuItem()
        item.submenu = applicationMenu
        menu.addItem(item)
        NSApp.mainMenu = menu
        record("session-running")
    }

    private func sendDockCommand(_ action: String) {
        guard cefPID > 0, getpgid(cefPID) == processGroup else { return }
        if action == "show", #available(macOS 14.0, *),
            let target = NSRunningApplication(processIdentifier: cefPID) {
            NSApp.yieldActivation(to: target)
        }
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.pwdft.kssolv.dock." + nonce), object: nonce,
            userInfo: ["pid": Int(cefPID), "action": action], deliverImmediately: true)
    }

    private func finishRunning() {
        guard running else { return }
        running = false
        timer?.invalidate()
        runtimeMonitor?.cancel()
        runtimeMonitor = nil
        windowProcessMonitor?.cancel()
        windowProcessMonitor = nil
        record("runtime-finished")
        // Clean only descendants of this launch, including any remaining CEF.
        if processGroup > 0 { kill(-processGroup, SIGTERM) }
        if let bytes = try? Data(contentsOf: channel.appendingPathComponent("status.json.dock.log")),
            let events = String(data: bytes, encoding: .utf8) { record("dock-bridge-events " + events) }
        try? FileManager.default.removeItem(at: channel)
        if let bridgeRegistration = bridgeRegistration { try? FileManager.default.removeItem(at: bridgeRegistration) }
        if terminating { NSApp.reply(toApplicationShouldTerminate: true) }
        else { NSApp.terminate(nil) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if running { sendDockCommand("show") }
        else { window?.makeKeyAndOrderFront(nil) }
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if running && !terminating { sendDockCommand("show") }
    }

    private func fail(_ message: String, alert: Bool = true) {
        guard !finished else { return }
        finished = true
        timer?.invalidate()
        windowProcessMonitor?.cancel()
        windowProcessMonitor = nil
        record((alert ? "failed " : "cancelled ") + message)
        if processGroup > 0 {
            let group = processGroup
            kill(-group, SIGTERM)
            // Kill only this launch's isolated process group, including CEF descendants.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { kill(-group, SIGKILL) }
        }
        window?.orderOut(nil)
        record("card-closed")
        if let bytes = try? Data(contentsOf: channel.appendingPathComponent("status.json.dock.log")),
            let events = String(data: bytes, encoding: .utf8) { record("failed-dock-bridge-events " + events) }
        try? FileManager.default.removeItem(at: channel)
        if let bridgeRegistration = bridgeRegistration { try? FileManager.default.removeItem(at: bridgeRegistration) }
        if alert {
            // A retired host must remain reachable if it needs to report a
            // failed startup. The owned Runtime group is already terminating.
            NSApp.setActivationPolicy(.regular)
            let dialog = NSAlert()
            dialog.messageText = "Unable to start KSSOLV Toolbox"
            dialog.informativeText = message
            dialog.alertStyle = .critical
            dialog.runModal()
        }
        // Give the process-group cleanup time to run even when no alert is shown.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { exit(1) }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { fail("Application startup was cancelled.", alert: false); return false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if running {
            record("dock-quit-requested")
            if cefPID > 0 && getpgid(cefPID) == processGroup {
                // Closing the native main window invokes MATLAB's save/cancel
                // confirmation. Never kill a session on a timer while that
                // confirmation may be waiting for the user.
                sendDockCommand("quit")
                return .terminateCancel
            }
            guard !terminating else { return .terminateLater }
            terminating = true
            let group = processGroup
            if group > 0 { kill(-group, SIGTERM) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if group > 0 { kill(-group, SIGKILL) }
                self.finishRunning()
            }
            return .terminateLater
        }
        if finished { return .terminateNow }
        fail("Application startup was cancelled.", alert: false)
        return .terminateCancel
    }

    private func record(_ text: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let bytes = Data((formatter.string(from: Date()) + " " + text + "\n").utf8)
        if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }
        if let file = try? FileHandle(forWritingTo: log) { file.seekToEndOfFile(); file.write(bytes); try? file.close() }
    }
}

func hostError(_ text: String) -> NSError { NSError(domain: "KSSOLV.Startup", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }

// The signed template stays in the app. A persistent, byte-verified cache copy
// supplies sibling Runtime aliases outside the sealed bundle. Keep it after exit
// because Dock may read its icon during the final removal animation.
func windowFingerprint(_ bundle: URL) throws -> String {
    let manager = FileManager.default
    guard manager.fileExists(atPath: bundle.appendingPathComponent("Contents/MacOS/MATLABWindow").path) else {
        throw hostError("The private window executable is missing.")
    }
    // Relative names come from the directory API: Foundation can expose the
    // same temporary directory as /var in a bundle URL and /private/var in its
    // enumerated children, so absolute-prefix subtraction is not reliable.
    let files = try manager.subpathsOfDirectory(atPath: bundle.path).sorted()
    var digest = SHA256()
    for relative in files {
        let file = bundle.appendingPathComponent(relative)
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true || values.isSymbolicLink == true else { continue }
        digest.update(data: Data(relative.utf8))
        digest.update(data: Data([0]))
        if values.isSymbolicLink == true {
            digest.update(data: Data(try manager.destinationOfSymbolicLink(atPath: file.path).utf8))
        } else { digest.update(data: try Data(contentsOf: file)) }
        digest.update(data: Data([0]))
    }
    return digest.finalize().map { String(format: "%02x", $0) }.joined()
}

func prepareWindowCache(resources: URL, runtime: String) throws -> URL {
    let manager = FileManager.default
    let template = resources.deletingLastPathComponent().appendingPathComponent("Helpers/KSSOLVWindow.app")
    let fingerprint = try windowFingerprint(template)
    let runtimeURL = URL(fileURLWithPath: runtime, isDirectory: true).resolvingSymlinksInPath()
    let key = SHA256.hash(data: Data((fingerprint + "\n" + runtimeURL.path).utf8))
        .map { String(format: "%02x", $0) }.joined()
    let root = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("KSSOLV Toolbox/window", isDirectory: true)
    try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let attributes = try manager.attributesOfItem(atPath: root.path)
    guard attributes[.type] as? FileAttributeType == .typeDirectory,
        (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
        ((attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0o777) & 0o077 == 0 else {
        throw hostError("The private window cache must be an owner-only directory.")
    }
    let layout = root.appendingPathComponent(key, isDirectory: true)
    let bundle = layout.appendingPathComponent("KSSOLVWindow.app", isDirectory: true)
    let bin = runtimeURL.appendingPathComponent("bin/maca64", isDirectory: true)
    let names = ["Frameworks"] + (try manager.contentsOfDirectory(atPath: bin.path).filter {
        $0.hasPrefix("matlabwindowhelper") && $0.hasSuffix(".app")
    })
    if !manager.fileExists(atPath: layout.path) {
        let staging = root.appendingPathComponent("prepare-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        do {
            try manager.copyItem(at: template, to: staging.appendingPathComponent("KSSOLVWindow.app"))
            for name in names {
                let source = bin.appendingPathComponent(name)
                guard manager.fileExists(atPath: source.path) else { throw hostError("Runtime window resource is missing: " + name) }
                try manager.createSymbolicLink(at: staging.appendingPathComponent(name), withDestinationURL: source)
            }
            do { try manager.moveItem(at: staging, to: layout) }
            catch {
                // Another launch may have completed the same immutable layout.
                guard manager.fileExists(atPath: layout.path) else { throw error }
                try manager.removeItem(at: staging)
            }
        } catch { try? manager.removeItem(at: staging); throw error }
    }
    guard try windowFingerprint(bundle) == fingerprint else {
        throw hostError("The cached private window differs from the signed application. Remove this cache folder and restart: " + layout.path)
    }
    let links = try manager.contentsOfDirectory(atPath: layout.path).filter { $0 != "KSSOLVWindow.app" }
    guard Set(links) == Set(names) else { throw hostError("Private window resources are incomplete.") }
    for name in links {
        guard name == "Frameworks" || (name.hasPrefix("matlabwindowhelper") && name.hasSuffix(".app")),
            try manager.destinationOfSymbolicLink(atPath: layout.appendingPathComponent(name).path) == bin.appendingPathComponent(name).path else {
            throw hostError("Private window Runtime resource links are invalid.")
        }
    }
    return bundle
}

func startupLocale(environment: [String: String]) -> String {
    let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("KSSOLV Toolbox/startup.json")
    if let bytes = try? Data(contentsOf: file),
        let data = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
        data["version"] as? Int == 1, let locale = data["locale"] as? String {
        return locale == "zh_CN" ? "zh_CN" : "en_US"
    }
    if let locale = environment["KSSOLV_LOCALE"], !locale.trimmingCharacters(in: .whitespaces).isEmpty {
        return locale == "zh_CN" ? "zh_CN" : "en_US"
    }
    let system = (Locale.preferredLanguages.first ?? "en-US").replacingOccurrences(of: "-", with: "_")
    return system == "zh_CN" || system.hasPrefix("zh_Hans") ? "zh_CN" : "en_US"
}

func runtimeRoot(config: [String: Any], environment: [String: String]) throws -> String {
    guard let release = config["runtimeRelease"] as? String else { throw hostError("Missing Runtime release in startup configuration.") }
    var candidates: [String] = []
    if let explicit = environment["KSSOLV_RUNTIME_ROOT"], !explicit.isEmpty { candidates = [explicit] }
    else {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: "/Library/Application Support/KSSOLV Toolbox/runtime.plist")),
            let saved = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let root = saved["RuntimeRoot"] as? String { candidates.append(root) }
        for entry in (environment["DYLD_LIBRARY_PATH"] ?? "").split(separator: ":") where entry.hasSuffix("/runtime/maca64") {
            candidates.append(String(entry.dropLast("/runtime/maca64".count)))
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        candidates += ["/Applications/MATLAB/MATLAB_Runtime/" + release,
            "/Applications/MATLAB/MATLABRuntime/" + release,
            "/Applications/MATLAB/MATLAB Runtime/" + release, "/Applications/MATLAB_Runtime/" + release,
            home + "/Applications/MATLAB/MATLAB_Runtime/" + release,
            home + "/Applications/MATLAB/MATLABRuntime/" + release,
            home + "/Applications/MATLAB_Runtime/" + release]
    }
    guard let root = candidates.first(where: { runtimeMatches($0, release: release, requirements: config["runtimeRequirements"] as? [String: Any]) })
        else { throw hostError("Matching MATLAB Runtime " + release + " is missing or incomplete. Run the KSSOLV Toolbox installer to configure it.") }
    return root
}

func runtimeMatches(_ root: String, release: String, requirements: [String: Any]?) -> Bool {
    let files = FileManager.default
    guard files.fileExists(atPath: root + "/runtime/maca64"), files.fileExists(atPath: root + "/bin/maca64") else { return false }
    // Native launcher fixtures intentionally omit packaged requirements. Every
    // production PKG seals the exact same requirements used by shell preflight.
    guard let requirements = requirements else { return true }
    guard files.isExecutableFile(atPath: root + "/bin/maca64/MATLABWindow.app/Contents/MacOS/MATLABWindow") else { return false }
    guard let version = requirements["RuntimeVersion"] as? String,
        let products = requirements["RequiredProductFiles"] as? [String], !products.isEmpty,
        let document = try? XMLDocument(contentsOf: URL(fileURLWithPath: root + "/VersionInfo.xml"), options: []),
        let actualRelease = try? document.nodes(forXPath: "/MathWorks_version_info/release").first?.stringValue,
        actualRelease == release,
        let actualVersion = try? document.nodes(forXPath: "/MathWorks_version_info/version").first?.stringValue,
        actualVersion.hasPrefix(version + ".") else { return false }
    if let minimum = requirements["RuntimeBuildVersion"] as? String, !minimum.isEmpty,
        actualVersion.compare(minimum, options: .numeric) == .orderedAscending { return false }
    guard products.allSatisfy({ !$0.contains("/") && files.isReadableFile(atPath: root + "/appdata/products/" + $0) }) else { return false }
    let check = Process()
    check.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
    check.arguments = [root + "/runtime/maca64/libmwmclmcrrt." + version + ".dylib", "-verify_arch", "arm64"]
    check.standardOutput = FileHandle.nullDevice
    check.standardError = FileHandle.nullDevice
    do { try check.run(); check.waitUntilExit(); return check.terminationStatus == 0 } catch { return false }
}

func spawnRunner(resources: URL, runtime: String, arguments: [String], environment: [String: String], group: pid_t = 0, resetSignals: Bool = false) throws -> pid_t {
    let runner = resources.appendingPathComponent("Runtime/run_KSSOLV_Toolbox.sh").path
    let values = ["/bin/sh", runner, runtime] + arguments
    let argv = values.map { strdup($0) } + [nil]
    let envp = environment.map { strdup($0.key + "=" + $0.value) } + [nil]
    defer { for value in argv { free(value) }; for value in envp { free(value) } }
    var attributes: posix_spawnattr_t?
    posix_spawnattr_init(&attributes)
    defer { posix_spawnattr_destroy(&attributes) }
    var flags = Int16(POSIX_SPAWN_SETPGROUP)
    if resetSignals {
        var defaults = sigset_t()
        sigemptyset(&defaults)
        for value in [SIGTERM, SIGINT, SIGHUP] { sigaddset(&defaults, value) }
        posix_spawnattr_setsigdefault(&attributes, &defaults)
        flags |= Int16(POSIX_SPAWN_SETSIGDEF)
    }
    posix_spawnattr_setflags(&attributes, flags)
    posix_spawnattr_setpgroup(&attributes, group)
    var pid: pid_t = 0
    let code = argv.withUnsafeBufferPointer { a in envp.withUnsafeBufferPointer { e in
        posix_spawn(&pid, "/bin/sh", nil, &attributes, UnsafeMutablePointer(mutating: a.baseAddress!), UnsafeMutablePointer(mutating: e.baseAddress!))
    } }
    if code != 0 { throw hostError("Unable to start MATLAB Runtime: " + String(cString: strerror(code))) }
    return pid
}

// Installer prewarm has no NSApplication or web card. Keep a supervisor alive
// for the validated bridge, in a dedicated group the installer can terminate.
func runPrewarm(resources: URL, config: [String: Any], arguments: [String]) throws -> Int32 {
    let manager = FileManager.default
    let group = getpid()
    guard setpgid(0, group) == 0 || getpgrp() == group else { throw hostError("Unable to isolate Runtime prewarm.") }
    // Group termination kills the children. The supervisor survives long enough
    // to reap them and remove only this launch's registry and communication files.
    for value in [SIGTERM, SIGINT, SIGHUP] { signal(value, SIG_IGN) }
    let nonce = UUID().uuidString
    let channel = manager.temporaryDirectory.appendingPathComponent("kssolv-prewarm-host-" + nonce, isDirectory: true)
    try manager.createDirectory(at: channel, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    let registry = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("KSSOLV Toolbox/dock", isDirectory: true)
    let registration = registry.appendingPathComponent("\(group).json")
    let bridgeLog = channel.appendingPathComponent("status.json.dock.log")
    defer {
        // Runtime normally tears down CEF itself; bound any residual helpers.
        func members() -> [pid_t] {
            var values = [pid_t](repeating: 0, count: 4096)
            let count = values.withUnsafeMutableBytes { proc_listpgrppids(group, $0.baseAddress, Int32($0.count)) }
            return values.prefix(max(0, min(values.count, Int(count)))).filter { $0 > 0 && $0 != group && getpgid($0) == group }
        }
        for pid in members() { kill(pid, SIGTERM) }
        for _ in 0..<40 {
            if members().isEmpty { break }
            usleep(50000)
        }
        for pid in members() { kill(pid, SIGKILL) }
        if let bytes = try? Data(contentsOf: bridgeLog) { FileHandle.standardError.write(bytes) }
        try? manager.removeItem(at: registration)
        try? manager.removeItem(at: channel)
    }
    var environment = ProcessInfo.processInfo.environment
    for key in ["KSSOLV_STARTUP_SIGNAL", "KSSOLV_STARTUP_COMPLETION", "KSSOLV_PREWARM_RESULT", "KSSOLV_PREWARM_NONCE"] { environment.removeValue(forKey: key) }
    environment["KSSOLV_STARTUP_NONCE"] = nonce
    environment["KSSOLV_DOCK_BRIDGE"] = "1"
    environment["KSSOLV_HOST_IN_BROWSER"] = "0"
    let runtime = try runtimeRoot(config: config, environment: environment)
    let privateWindow = try prepareWindowCache(resources: resources, runtime: runtime)
    try manager.createDirectory(at: registry, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let metadata: [String: Any] = ["pgid": Int(group), "host": Int(group), "nonce": nonce, "mode": "prewarm",
        "signal": channel.appendingPathComponent("status.json").path,
        "library": resources.deletingLastPathComponent().appendingPathComponent("Frameworks/KssolvDockBridge.dylib").resolvingSymlinksInPath().path,
        "icon": resources.appendingPathComponent("KssolvBrand.icns").path,
        "executable": Bundle.main.executableURL!.resolvingSymlinksInPath().path,
        "runtimeExecutable": resources.deletingLastPathComponent().appendingPathComponent("Helpers/KSSOLV_Toolbox.app/Contents/MacOS/KSSOLV_Toolbox").resolvingSymlinksInPath().path,
        "sourceWindowExecutable": runtime + "/bin/maca64/MATLABWindow.app/Contents/MacOS/MATLABWindow",
        "windowExecutable": privateWindow.appendingPathComponent("Contents/MacOS/MATLABWindow").path]
    // Publish before spawn: even a fast child can validate its identity immediately.
    try JSONSerialization.data(withJSONObject: metadata).write(to: registration, options: .atomic)
    try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: registration.path)
    let child = try spawnRunner(resources: resources, runtime: runtime, arguments: arguments, environment: environment, group: group, resetSignals: true)
    var status: Int32 = 0
    while waitpid(child, &status, 0) < 0 {
        if errno != EINTR { throw hostError("Unable to wait for Runtime prewarm.") }
    }
    return status & 0x7f == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
}

// Build-time rendering uses the same native host source; no extra compiler
// target or image-processing dependency is needed for the shared Dock asset.
func exportDockIconset(source: String, output: String) throws {
    guard let logo = NSImage(contentsOfFile: source) else { throw hostError("Unable to read the company logo.") }
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let side = points * scale
            guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw hostError("Unable to render the Dock icon.") }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            context.imageInterpolation = .high
            let bounds = NSRect(x: 0, y: 0, width: side, height: side)
            NSColor.clear.setFill()
            bounds.fill(using: .copy)
            NSColor.white.setFill()
            let plate = bounds.insetBy(dx: Double(side) * 0.06, dy: Double(side) * 0.06)
            NSBezierPath(roundedRect: plate, xRadius: Double(side) * 0.18, yRadius: Double(side) * 0.18).fill()
            logo.draw(in: bounds.insetBy(dx: Double(side) * 0.10, dy: Double(side) * 0.10),
                from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            guard let bytes = bitmap.representation(using: .png, properties: [:]) else { throw hostError("Unable to encode the Dock icon.") }
            let suffix = scale == 2 ? "@2x" : ""
            try bytes.write(to: URL(fileURLWithPath: output).appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
        }
    }
}

if CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "--export-dock-iconset" {
    do { try exportDockIconset(source: CommandLine.arguments[2], output: CommandLine.arguments[3]); exit(0) }
    catch { fputs("Dock icon rendering failed: \(error)\n", stderr); exit(1) }
}

do {
    guard let resources = Bundle.main.resourceURL else { throw hostError("Missing application resources.") }
    var config = try JSONSerialization.jsonObject(with: Data(contentsOf: resources.appendingPathComponent("startup-host.json"))) as? [String: Any] ?? [:]
    let requirementsFile = resources.appendingPathComponent("runtime-requirements.plist")
    if FileManager.default.fileExists(atPath: requirementsFile.path) {
        config["runtimeRequirements"] = try PropertyListSerialization.propertyList(from: Data(contentsOf: requirementsFile), format: nil)
    }
    guard config["protocolVersion"] as? Int == 1 else { throw hostError("Unsupported startup host protocol.") }
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments == ["--check-runtime"] {
        print(try runtimeRoot(config: config, environment: ProcessInfo.processInfo.environment))
        exit(0)
    }
    if arguments.contains("--prewarm") {
        exit(try runPrewarm(resources: resources, config: config, arguments: arguments))
    }
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let host = try StartupHost(resources: resources, config: config, arguments: arguments)
    app.delegate = host
    withExtendedLifetime(host) { app.run() }
} catch {
    if CommandLine.arguments.contains("--prewarm") || CommandLine.arguments.contains("--check-runtime") {
        fputs("KSSOLV prewarm: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
    let dialog = NSAlert()
    dialog.messageText = "Unable to start KSSOLV Toolbox"
    dialog.informativeText = error.localizedDescription
    dialog.runModal()
    exit(1)
}
