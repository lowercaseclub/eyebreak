import AppKit

class BreakScheduler {
    private let interval: TimeInterval = 20 * 60  // 20 minutes
    private let snoozeDelay: TimeInterval = 60     // 1 minute
    private let maxSnoozes = 3
    private let maxMeetingDefers = 6

    private var timer: DispatchSourceTimer?
    private var snoozeTimer: DispatchSourceTimer?
    private var pauseTimer: DispatchSourceTimer?
    private var snoozeCount = 0
    private var meetingDeferCount = 0
    private var overlay: OverlayWindow?
    private var isPaused = false
    private var nextFireDate: Date?

    private let lastBreakKey = "lastBreakTimestamp"

    var onStatusChange: (() -> Void)?

    var statusText: String {
        if isPaused {
            return "Paused"
        }
        if overlay != nil {
            return "Break in progress"
        }
        guard let next = nextFireDate else {
            return "Scheduling..."
        }
        let remaining = max(0, next.timeIntervalSinceNow)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "Next break in %d:%02d", minutes, seconds)
    }

    func start() {
        scheduleFromLastBreak()

        // Recalculate on wake from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            self.scheduleFromLastBreak()
        }
    }

    func triggerNow() {
        cancelTimers()
        onTimerFired()
    }

    func pause(duration: TimeInterval = 3600) {
        isPaused = true
        cancelTimers()
        onStatusChange?()

        pauseTimer = DispatchSource.makeTimerSource(queue: .main)
        pauseTimer?.schedule(deadline: .now() + duration)
        pauseTimer?.setEventHandler { [weak self] in
            self?.resume()
        }
        pauseTimer?.resume()
    }

    func resume() {
        isPaused = false
        pauseTimer?.cancel()
        pauseTimer = nil
        scheduleFromLastBreak()
        onStatusChange?()
    }

    // MARK: - Private

    private func scheduleFromLastBreak() {
        let lastBreak = UserDefaults.standard.double(forKey: lastBreakKey)
        let now = Date().timeIntervalSince1970
        let elapsed = now - lastBreak

        var delay: TimeInterval
        if lastBreak == 0 || elapsed >= interval {
            delay = interval  // No record or stale — full interval
        } else {
            delay = interval - elapsed
        }

        scheduleTimer(after: delay)
    }

    private func scheduleTimer(after delay: TimeInterval) {
        cancelTimers()
        nextFireDate = Date().addingTimeInterval(delay)
        onStatusChange?()

        timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(deadline: .now() + delay)
        timer?.setEventHandler { [weak self] in
            self?.onTimerFired()
        }
        timer?.resume()
    }

    private func onTimerFired() {
        nextFireDate = nil

        // Check for meeting
        if MeetingDetector.isMeetingActive() {
            meetingDeferCount += 1
            if meetingDeferCount >= maxMeetingDefers {
                NSLog("Meeting defer limit reached (%d/%d) — forcing break", meetingDeferCount, maxMeetingDefers)
                meetingDeferCount = 0
                showBreakOverlay(allowSnooze: snoozeCount < maxSnoozes)
            } else {
                NSLog("Meeting in progress — deferring break (%d/%d)", meetingDeferCount, maxMeetingDefers)
                scheduleTimer(after: interval)
            }
        } else {
            meetingDeferCount = 0
            showBreakOverlay(allowSnooze: snoozeCount < maxSnoozes)
        }
    }

    private func showBreakOverlay(allowSnooze: Bool) {
        let ov = OverlayWindow()
        ov.allowSnooze = allowSnooze
        self.overlay = ov

        ov.onCompleted = { [weak self] in
            guard let self = self else { return }
            self.overlay = nil
            self.snoozeCount = 0
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastBreakKey)
            self.scheduleTimer(after: self.interval)
        }

        ov.onSnoozed = { [weak self] in
            guard let self = self else { return }
            self.overlay = nil
            self.snoozeCount += 1
            NSLog("Snoozed (%d/%d)", self.snoozeCount, self.maxSnoozes)

            if self.snoozeCount >= self.maxSnoozes {
                NSLog("Max snoozes reached — forcing break")
                self.showBreakOverlay(allowSnooze: false)
            } else {
                self.scheduleTimer(after: self.snoozeDelay)
            }
        }

        ov.show()
        onStatusChange?()
    }

    private func cancelTimers() {
        timer?.cancel()
        timer = nil
        snoozeTimer?.cancel()
        snoozeTimer = nil
        nextFireDate = nil
    }
}
