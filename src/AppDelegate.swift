import AppKit
import ServiceManagement
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var scheduler: BreakScheduler!
    private var statusMenuItem: NSMenuItem!
    private var pauseMenuItem: NSMenuItem!
    private var loginMenuItem: NSMenuItem!
    private var statusUpdateTimer: Timer?
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        scheduler = BreakScheduler()
        scheduler.onStatusChange = { [weak self] in
            self?.updateStatusMenu()
        }

        setupMenuBar()
        scheduler.start()

        // Update the status text every 10s so the countdown stays fresh
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.updateStatusMenu()
        }

        // First-launch: prompt to enable login item
        if !UserDefaults.standard.bool(forKey: "hasPromptedLoginItem") {
            UserDefaults.standard.set(true, forKey: "hasPromptedLoginItem")
            promptLoginItem()
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "eye", accessibilityDescription: "EyeBreak") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "\u{25C9}"  // Unicode fallback
            }
        }

        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: scheduler.statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Take Break Now", action: #selector(takeBreakNow), keyEquivalent: "b"))

        pauseMenuItem = NSMenuItem(title: "Pause 1 Hour", action: #selector(togglePause), keyEquivalent: "p")
        menu.addItem(pauseMenuItem)

        menu.addItem(NSMenuItem.separator())

        loginMenuItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginMenuItem.state = isLoginItemEnabled() ? .on : .off
        menu.addItem(loginMenuItem)

        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit EyeBreak", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func updateStatusMenu() {
        statusMenuItem?.title = scheduler.statusText
        if scheduler.statusText == "Paused" {
            pauseMenuItem?.title = "Resume"
        } else {
            pauseMenuItem?.title = "Pause 1 Hour"
        }
    }

    // MARK: - Actions

    @objc private func takeBreakNow() {
        scheduler.triggerNow()
    }

    @objc private func togglePause() {
        if scheduler.statusText == "Paused" {
            scheduler.resume()
        } else {
            scheduler.pause()
        }
    }

    @objc private func toggleLoginItem() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if service.status == .enabled {
                    try service.unregister()
                    loginMenuItem.state = .off
                } else {
                    try service.register()
                    loginMenuItem.state = .on
                }
            } catch {
                NSLog("Login item toggle failed: %@", error.localizedDescription)
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Login Item

    private func isLoginItemEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func promptLoginItem() {
        if #available(macOS 13.0, *) {
            let alert = NSAlert()
            alert.messageText = "Launch EyeBreak at Login?"
            alert.informativeText = "EyeBreak can start automatically when you log in so you never miss a break."
            alert.addButton(withTitle: "Enable")
            alert.addButton(withTitle: "Not Now")
            alert.alertStyle = .informational

            if alert.runModal() == .alertFirstButtonReturn {
                try? SMAppService.mainApp.register()
                loginMenuItem?.state = .on
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
