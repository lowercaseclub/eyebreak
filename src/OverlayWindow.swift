import AppKit

class OverlayWindow {
    var onCompleted: (() -> Void)?
    var onSnoozed: (() -> Void)?
    var allowSnooze: Bool = true

    private var mainWindow: NSWindow!
    private var overlayWindows: [NSWindow] = []
    private var countdownLabel: NSTextField!
    private var snoozeButton: NSButton!
    private var secondsRemaining = 20
    private var timer: Timer?
    private var eventMonitor: Any?

    func show() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        mainWindow = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        mainWindow.level = .screenSaver
        mainWindow.backgroundColor = .black
        mainWindow.isOpaque = true
        mainWindow.hasShadow = false
        mainWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        mainWindow.ignoresMouseEvents = false

        let contentView = NSView(frame: frame)
        mainWindow.contentView = contentView

        let titleLabel = NSTextField(labelWithString: "Look 6 metres away")
        titleLabel.font = NSFont.systemFont(ofSize: 48, weight: .light)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        countdownLabel = NSTextField(labelWithString: "\(secondsRemaining)")
        countdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 120, weight: .ultraLight)
        countdownLabel.textColor = .white
        countdownLabel.alignment = .center
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countdownLabel)

        snoozeButton = NSButton(title: "Snooze 1 min", target: self, action: #selector(snooze))
        snoozeButton.bezelStyle = .rounded
        snoozeButton.font = NSFont.systemFont(ofSize: 16)
        snoozeButton.translatesAutoresizingMaskIntoConstraints = false
        snoozeButton.isHidden = !allowSnooze
        contentView.addSubview(snoozeButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -80),
            countdownLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            countdownLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 40),
            snoozeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            snoozeButton.topAnchor.constraint(equalTo: countdownLabel.bottomAnchor, constant: 40),
        ])

        mainWindow.makeKeyAndOrderFront(nil)

        // Cover other screens with black
        for otherScreen in NSScreen.screens where otherScreen != screen {
            let overlay = NSWindow(
                contentRect: otherScreen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            overlay.level = .screenSaver
            overlay.backgroundColor = .black
            overlay.isOpaque = true
            overlay.hasShadow = false
            overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            overlay.ignoresMouseEvents = true
            overlay.orderFront(nil)
            overlayWindows.append(overlay)
        }

        NSApp.activate(ignoringOtherApps: true)

        // ESC triggers snooze
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.snooze()
                return nil
            }
            return event
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func dismiss() {
        timer?.invalidate()
        timer = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        mainWindow?.close()
        mainWindow = nil
        for overlay in overlayWindows {
            overlay.close()
        }
        overlayWindows.removeAll()
        secondsRemaining = 20
    }

    private func tick() {
        secondsRemaining -= 1
        if secondsRemaining <= 0 {
            countdownLabel.stringValue = "Done!"
            countdownLabel.font = NSFont.systemFont(ofSize: 72, weight: .light)
            timer?.invalidate()
            timer = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.dismiss()
                self?.onCompleted?()
            }
        } else {
            countdownLabel.stringValue = "\(secondsRemaining)"
        }
    }

    @objc private func snooze() {
        guard allowSnooze else { return }
        dismiss()
        onSnoozed?()
    }
}
