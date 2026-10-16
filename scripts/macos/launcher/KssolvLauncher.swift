import AppKit
import WebKit
import Darwin

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
    private var timer: Timer?
    private var child: pid_t = 0
    private var processGroup: pid_t = 0
    private var childExited = false
    private var acknowledged = false
    private var finished = false
    private var started = Date()
    private var presentationChecking = false
    private var presentationPainted = false

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
        guard let bytes = try? JSONSerialization.data(withJSONObject: ["language": language, "version": config["version"] as? String ?? ""]),
            let metadata = String(data: bytes, encoding: .utf8) else { fail("Unable to read startup metadata."); return }
        controller.addUserScript(WKUserScript(source: "window.kssolvStartup=\(metadata);", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 494), configuration: configuration)
        web.navigationDelegate = self
        window = NSWindow(contentRect: web.bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = "KSSOLV Toolbox"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = web
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let folder = resources.appendingPathComponent("startup", isDirectory: true)
        web.loadFileURL(folder.appendingPathComponent("index.html"), allowingReadAccessTo: folder)
        started = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.poll() }
    }

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
            environment["KSSOLV_STARTUP_COMPLETION"] = log.deletingLastPathComponent().appendingPathComponent("startup-loaded.json").path
            let runtime = try runtimeRoot(config: config, environment: environment)
            child = try spawnRunner(resources: resources, runtime: runtime, arguments: arguments, environment: environment)
            processGroup = child
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
        guard !finished else { return }
        guard child > 0 else {
            if Date().timeIntervalSince(started) > 15 { fail("The local HTML startup card could not be rendered.") }
            return
        }
        var exitStatus: Int32 = 0
        if !childExited && waitpid(child, &exitStatus, WNOHANG) == child { childExited = true }
        let signal = channel.appendingPathComponent("status.json")
        do {
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
        timer?.invalidate()
        window.orderOut(nil)
        record("card-closed")
        web.configuration.userContentController.removeAllScriptMessageHandlers()
        try? FileManager.default.removeItem(at: channel)
        // The Runtime process group is intentionally retained on successful handoff.
        NSApp.terminate(nil)
    }

    private func fail(_ message: String, alert: Bool = true) {
        guard !finished else { return }
        finished = true
        timer?.invalidate()
        record((alert ? "failed " : "cancelled ") + message)
        if processGroup > 0 {
            let group = processGroup
            kill(-group, SIGTERM)
            // Kill only this launch's isolated process group, including CEF descendants.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { kill(-group, SIGKILL) }
        }
        window?.orderOut(nil)
        record("card-closed")
        try? FileManager.default.removeItem(at: channel)
        if alert {
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
        for entry in (environment["DYLD_LIBRARY_PATH"] ?? "").split(separator: ":") where entry.hasSuffix("/runtime/maca64") {
            candidates.append(String(entry.dropLast("/runtime/maca64".count)))
        }
        candidates += ["/Applications/MATLAB/MATLAB_Runtime/" + release,
            "/Applications/MATLAB_Runtime/" + release, "/Applications/MATLAB/MATLAB Runtime/" + release]
    }
    guard let root = candidates.first(where: {
        FileManager.default.fileExists(atPath: $0 + "/runtime/maca64") &&
        FileManager.default.fileExists(atPath: $0 + "/bin/maca64")
    }) else { throw hostError("Matching MATLAB Runtime " + release + " is not installed. Set KSSOLV_RUNTIME_ROOT if it is installed elsewhere.") }
    return root
}

func spawnRunner(resources: URL, runtime: String, arguments: [String], environment: [String: String]) throws -> pid_t {
    let runner = resources.appendingPathComponent("Runtime/run_KSSOLV_Toolbox.sh").path
    let values = ["/bin/sh", runner, runtime] + arguments
    let argv = values.map { strdup($0) } + [nil]
    let envp = environment.map { strdup($0.key + "=" + $0.value) } + [nil]
    defer { for value in argv { free(value) }; for value in envp { free(value) } }
    var attributes: posix_spawnattr_t?
    posix_spawnattr_init(&attributes)
    defer { posix_spawnattr_destroy(&attributes) }
    posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
    posix_spawnattr_setpgroup(&attributes, 0)
    var pid: pid_t = 0
    let code = argv.withUnsafeBufferPointer { a in envp.withUnsafeBufferPointer { e in
        posix_spawn(&pid, "/bin/sh", nil, &attributes, UnsafeMutablePointer(mutating: a.baseAddress!), UnsafeMutablePointer(mutating: e.baseAddress!))
    } }
    if code != 0 { throw hostError("Unable to start MATLAB Runtime: " + String(cString: strerror(code))) }
    return pid
}

let app = NSApplication.shared
do {
    guard let resources = Bundle.main.resourceURL else { throw hostError("Missing application resources.") }
    let config = try JSONSerialization.jsonObject(with: Data(contentsOf: resources.appendingPathComponent("startup-host.json"))) as? [String: Any] ?? [:]
    guard config["protocolVersion"] as? Int == 1 else { throw hostError("Unsupported startup host protocol.") }
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.contains("--prewarm") {
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "KSSOLV_STARTUP_SIGNAL")
        environment.removeValue(forKey: "KSSOLV_STARTUP_NONCE")
        environment.removeValue(forKey: "KSSOLV_STARTUP_COMPLETION")
        let runtime = try runtimeRoot(config: config, environment: environment)
        // Preserve the existing prewarm process chain and its timeout/cleanup behavior.
        let runner = resources.appendingPathComponent("Runtime/run_KSSOLV_Toolbox.sh").path
        let argv = (["/bin/sh", runner, runtime] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup($0.key + "=" + $0.value) } + [nil]
        argv.withUnsafeBufferPointer { a in envp.withUnsafeBufferPointer { e in
            _ = execve("/bin/sh", UnsafeMutablePointer(mutating: a.baseAddress!), UnsafeMutablePointer(mutating: e.baseAddress!))
        } }
        throw hostError("Unable to execute the Runtime prewarm runner: " + String(cString: strerror(errno)))
    }
    app.setActivationPolicy(.regular)
    let host = try StartupHost(resources: resources, config: config, arguments: arguments)
    app.delegate = host
    withExtendedLifetime(host) { app.run() }
} catch {
    let dialog = NSAlert()
    dialog.messageText = "Unable to start KSSOLV Toolbox"
    dialog.informativeText = error.localizedDescription
    dialog.runModal()
    exit(1)
}
