import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var statusLine: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var enabledItem: NSMenuItem!
    private var tapItem: NSMenuItem!
    private var clickItem: NSMenuItem!
    private var fingerItems: [NSMenuItem] = []
    private var loginItem: NSMenuItem!
    private let monitor = TouchMonitor.shared
    private let interceptor = ClickInterceptor()
    private var frameworkMissing = false
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Preferences.registerDefaults()
        configureMenu()
        enableLaunchAtLoginOnFirstRun()

        monitor.onTap = { [weak self] in
            guard let self, Preferences.enabled, interceptor.isRunning else { return }
            ClickInterceptor.postMiddleClick()
        }
        interceptor.onPress = { [weak self] in self?.monitor.cancelTap() }
        interceptor.shouldConvert = { [weak self] in
            guard let self else { return false }
            return Preferences.enabled && Preferences.clickEnabled && monitor.fingerCount == Preferences.fingers
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.monitor.scheduleRestart()
        }

        applySettings()
        // Shows the system prompt once; the menu explains how to grant access if it is still missing.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) || !interceptor.start() { waitForPermission() }
        refreshMenu()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem.button?.performClick(nil)
        return true
    }

    private func applySettings() {
        monitor.configure(fingers: Preferences.fingers, tapEnabled: Preferences.enabled && Preferences.tapEnabled)
        if Preferences.enabled {
            frameworkMissing = !monitor.start()
        } else {
            monitor.stop()
        }
        refreshMenu()
    }

    /// Accessibility access is granted in System Settings while the app runs, so poll until the tap can be created.
    private func waitForPermission() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self, AXIsProcessTrusted(), interceptor.start() else { return }
            timer.invalidate()
            permissionTimer = nil
            refreshMenu()
        }
    }

    // MARK: Menu

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "hand.tap", accessibilityDescription: "MacMiddleClick")
        let menu = NSMenu()
        menu.autoenablesItems = false
        statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        permissionItem = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)
        menu.addItem(.separator())

        enabledItem = item("Enabled", #selector(toggleEnabled), in: menu)
        tapItem = item("", #selector(toggleTap), in: menu)
        clickItem = item("", #selector(toggleClick), in: menu)
        let fingersItem = NSMenuItem(title: "Fingers", action: nil, keyEquivalent: "")
        let fingersMenu = NSMenu()
        fingerItems = [3, 4].map { count in
            let item = NSMenuItem(title: count == 3 ? "Three" : "Four", action: #selector(setFingers(_:)), keyEquivalent: "")
            item.target = self
            item.tag = count
            fingersMenu.addItem(item)
            return item
        }
        fingersItem.submenu = fingersMenu
        menu.addItem(fingersItem)
        menu.addItem(.separator())

        loginItem = item("Launch at Login", #selector(toggleLaunchAtLogin), in: menu)
        menu.addItem(withTitle: "Quit MacMiddleClick", action: #selector(quit), keyEquivalent: "q").target = self
        menu.delegate = self
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, in menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    func menuWillOpen(_ menu: NSMenu) { refreshMenu() }

    private func refreshMenu() {
        let fingers = Preferences.fingers == 3 ? "Three" : "Four"
        let status: String
        if frameworkMissing {
            status = "Trackpad access is unavailable on this macOS"
        } else if !interceptor.isRunning {
            status = "Needs Accessibility access"
        } else if !Preferences.enabled {
            status = "Paused"
        } else if monitor.deviceCount == 0 {
            status = "No trackpad found"
        } else {
            status = "Active"
        }
        statusLine.title = status
        permissionItem.isHidden = interceptor.isRunning
        enabledItem.state = Preferences.enabled ? .on : .off
        tapItem.title = "\(fingers)-Finger Tap"
        tapItem.state = Preferences.tapEnabled ? .on : .off
        clickItem.title = "\(fingers)-Finger Click"
        clickItem.state = Preferences.clickEnabled ? .on : .off
        for item in fingerItems { item.state = item.tag == Preferences.fingers ? .on : .off }
        let login = SMAppService.mainApp.status
        loginItem.state = login == .enabled ? .on : login == .requiresApproval ? .mixed : .off
        statusItem.button?.appearsDisabled = status != "Active"
        statusItem.button?.toolTip = "MacMiddleClick · \(status)"
    }

    @objc private func toggleEnabled() {
        Preferences.enabled.toggle()
        applySettings()
    }

    @objc private func toggleTap() {
        Preferences.tapEnabled.toggle()
        applySettings()
    }

    @objc private func toggleClick() {
        Preferences.clickEnabled.toggle()
        refreshMenu()
    }

    @objc private func setFingers(_ sender: NSMenuItem) {
        Preferences.fingers = sender.tag
        applySettings()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Launch at Login defaults to on, but only once, so turning it off in the menu sticks.
    private func enableLaunchAtLoginOnFirstRun() {
        let key = "launchAtLoginConfigured"
        // Skip `swift run` binaries and translocated copies, whose paths would not survive a restart.
        let path = Bundle.main.bundlePath
        guard !UserDefaults.standard.bool(forKey: key), path.hasSuffix(".app"), !path.contains("/AppTranslocation/") else { return }
        if SMAppService.mainApp.status == .notRegistered, (try? SMAppService.mainApp.register()) == nil { return }
        UserDefaults.standard.set(true, forKey: key)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Launch at Login could not be changed"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        refreshMenu()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
