import AppKit
import SwiftUI

struct ReminderClock {
    static let interval: TimeInterval = 30 * 60
    var deadline: Date?
    var presenting = false
    var paused = false

    mutating func start(now: Date, delay: TimeInterval = Self.interval) {
        paused = false
        presenting = false
        deadline = now.addingTimeInterval(delay)
    }

    mutating func tick(now: Date) -> Bool {
        guard !paused, !presenting, let deadline, now >= deadline else { return false }
        presenting = true
        self.deadline = nil
        return true
    }

    mutating func pause() {
        paused = true
        presenting = false
        deadline = nil
    }

    mutating func show() {
        paused = false
        presenting = true
        deadline = nil
    }
}

final class ReminderWindow: NSWindow {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onEscape?() } else { super.keyDown(with: event) }
    }
}

struct WaterView: View {
    let onDrink: () -> Void
    let onSnooze: () -> Void
    let onPause: () -> Void
    private let ink = Color(red: 0.12, green: 0.20, blue: 0.23)
    private let blue = Color(red: 0.16, green: 0.43, blue: 0.57)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.96, green: 0.96, blue: 0.93)
                Circle().fill(blue.opacity(0.045))
                    .frame(width: 640, height: 640)
                    .offset(x: geometry.size.width * 0.39, y: geometry.size.height * 0.39)
                VStack(spacing: 0) {
                    HStack(spacing: 9) {
                        Image(systemName: "drop.fill").foregroundStyle(blue)
                        Text("喝水时间").font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text("给自己一个小小的停顿").font(.system(size: 13))
                            .foregroundStyle(ink.opacity(0.5))
                    }
                    Spacer(minLength: 16)
                    ZStack {
                        Circle().fill(.white.opacity(0.85)).frame(width: 150, height: 150)
                        Circle().stroke(blue.opacity(0.12), lineWidth: 1).frame(width: 180, height: 180)
                        Image(systemName: "drop.fill")
                            .font(.system(size: 72, weight: .light)).foregroundStyle(blue)
                        Image(systemName: "sparkle")
                            .font(.system(size: 22)).foregroundStyle(blue.opacity(0.65))
                            .offset(x: 55, y: -48)
                    }
                    .padding(.bottom, 34)
                    Text("忙了半小时，喝口水吧。")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text("放下手边的事，让眼睛也休息一下。")
                        .font(.system(size: 18)).foregroundStyle(ink.opacity(0.58))
                        .padding(.top, 18)
                    HStack(spacing: 14) {
                        Button(action: onDrink) {
                            Label("我喝水了", systemImage: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 180, height: 54)
                                .background(blue, in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(.white)
                        }.buttonStyle(.plain).keyboardShortcut(.defaultAction)
                        Button(action: onSnooze) {
                            Text("10 分钟后提醒")
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 180, height: 54)
                                .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }.padding(.top, 40)
                    Text("喝完这一口，30 分钟后再见。")
                        .font(.system(size: 13)).foregroundStyle(ink.opacity(0.45))
                        .padding(.top, 20)
                    Spacer(minLength: 16)
                    HStack {
                        Text("ESC 关闭 · 30 分钟后再提醒")
                            .font(.system(size: 12)).foregroundStyle(ink.opacity(0.45))
                        Spacer()
                        Button("暂停提醒", action: onPause)
                            .font(.system(size: 13)).buttonStyle(.plain)
                            .foregroundStyle(ink.opacity(0.6))
                    }
                }.padding(40)
            }.foregroundStyle(ink)
        }.ignoresSafeArea()
    }
}

final class PanelState: ObservableObject {
    @Published var status = ""
    @Published var paused = false
}

struct ControlPanel: View {
    @ObservedObject var state: PanelState
    let onTest: () -> Void
    let onPause: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "drop.fill").font(.system(size: 38)).foregroundStyle(.blue)
            Text("喝水提醒").font(.system(size: 25, weight: .semibold))
            Text(state.status).font(.system(size: 20, design: .monospaced))
            Text("每 30 分钟全屏提醒一次\n关闭此窗口后，仍在菜单栏后台运行。")
                .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("立即测试全屏提醒", action: onTest).buttonStyle(.borderedProminent)
            HStack {
                Button(state.paused ? "继续提醒" : "暂停提醒", action: onPause)
                Button("重新计时", action: onRestart)
                Button("退出", action: onQuit)
            }
        }.padding(32).frame(width: 390, height: 340)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var clock = ReminderClock()
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var windows: [ReminderWindow] = []
    private var previousApp: NSRunningApplication?
    private var panel: NSWindow?
    private let panelState = PanelState()
    private var restorePanel = false
    private let remainingItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "暂停提醒", action: #selector(togglePause), keyEquivalent: "p")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second launch reuses the running app instead of creating duplicate timers.
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "喝水提醒")
        statusItem.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "喝水提醒 · 每 30 分钟", action: nil, keyEquivalent: ""))
        menu.addItem(remainingItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "打开控制面板", action: #selector(openPanel), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "立即测试全屏提醒", action: #selector(showNow), keyEquivalent: "t"))
        menu.addItem(pauseItem)
        menu.addItem(NSMenuItem(title: "重新计时 30 分钟", action: #selector(restart), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出喝水提醒", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
        let args = CommandLine.arguments
        let testDelay: TimeInterval? = args.firstIndex(of: "--test-delay").flatMap {
            args.indices.contains($0 + 1) ? Double(args[$0 + 1]) : nil
        }
        clock.start(now: Date(), delay: max(1, testDelay ?? ReminderClock.interval))
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        updateMenu()
        openPanel()
    }

    @objc private func openPanel() {
        if panel == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 454, height: 404), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "喝水提醒"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ControlPanel(state: panelState,
                onTest: { [weak self] in self?.showNow() },
                onPause: { [weak self] in self?.togglePause() },
                onRestart: { [weak self] in self?.restart() },
                onQuit: { [weak self] in self?.quit() }))
            window.center()
            panel = window
        }
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !clock.presenting { openPanel() }
        return true
    }

    private func tick() {
        if clock.tick(now: Date()) { presentReminder() }
        updateMenu()
    }

    private func updateMenu() {
        pauseItem.title = clock.paused ? "继续提醒（30 分钟后）" : "暂停提醒"
        if clock.paused {
            remainingItem.title = "已暂停"; statusItem.button?.title = " 已暂停"
        } else if clock.presenting {
            remainingItem.title = "现在，喝口水吧"; statusItem.button?.title = " 喝水啦"
        } else {
            let seconds = max(0, Int(ceil(clock.deadline?.timeIntervalSinceNow ?? 0)))
            let countdown = String(format: "%02d:%02d", seconds / 60, seconds % 60)
            remainingItem.title = "下次提醒：\(countdown) 后"
            statusItem.button?.title = " \(countdown)"
        }
        panelState.status = remainingItem.title
        panelState.paused = clock.paused
    }

    @objc private func showNow() {
        guard !clock.presenting else { return }
        clock.show()
        presentReminder()
        updateMenu()
    }

    private func presentReminder() {
        previousApp = NSWorkspace.shared.frontmostApplication
        restorePanel = panel?.isVisible == true
        panel?.orderOut(nil)
        buildWindows()
    }

    private func buildWindows() {
        for screen in NSScreen.screens {
            let window = ReminderWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: true)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            window.backgroundColor = .windowBackgroundColor
            window.onEscape = { [weak self] in self?.finish(delay: ReminderClock.interval) }
            window.contentView = NSHostingView(rootView: WaterView(
                onDrink: { [weak self] in self?.finish(delay: ReminderClock.interval) },
                onSnooze: { [weak self] in self?.finish(delay: 10 * 60) },
                onPause: { [weak self] in self?.pause() }
            ))
            windows.append(window)
            window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
    }

    private func closeWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()
        if restorePanel { panel?.makeKeyAndOrderFront(nil) }
        restorePanel = false
        if let app = previousApp, app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            app.activate(options: [])
        }
        previousApp = nil
    }

    private func finish(delay: TimeInterval) {
        closeWindows()
        clock.start(now: Date(), delay: delay)
        updateMenu()
    }

    private func pause() {
        closeWindows()
        clock.pause()
        updateMenu()
    }

    @objc private func togglePause() {
        if clock.paused { finish(delay: ReminderClock.interval) } else { pause() }
    }
    @objc private func restart() { finish(delay: ReminderClock.interval) }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func woke() { tick() }
    @objc private func screensChanged() {
        guard clock.presenting else { return }
        windows.forEach { $0.close() }
        windows.removeAll()
        buildWindows()
    }
}

func selfTest() {
    let now = Date(timeIntervalSince1970: 1000)
    var clock = ReminderClock()
    var checks = 0
    func check(_ condition: Bool, _ label: String) {
        guard condition else { fatalError("FAIL: \(label)") }
        checks += 1
        print("PASS: \(label)")
    }
    clock.start(now: now)
    check(clock.deadline == now.addingTimeInterval(1800), "default interval is 30 minutes")
    check(!clock.tick(now: now.addingTimeInterval(1799)), "does not fire early")
    check(clock.tick(now: now.addingTimeInterval(1800)), "fires at deadline")
    check(!clock.tick(now: now.addingTimeInterval(3600)), "does not stack reminders")
    clock.start(now: now, delay: 600)
    check(!clock.tick(now: now.addingTimeInterval(599)), "snooze waits 10 minutes")
    check(clock.tick(now: now.addingTimeInterval(600)), "snooze fires")
    clock.pause()
    check(!clock.tick(now: now.addingTimeInterval(10000)), "paused clock never fires")
    clock.start(now: now)
    check(!clock.paused && clock.deadline == now.addingTimeInterval(1800), "resume resets interval")
    check(clock.tick(now: now.addingTimeInterval(7200)), "wake after deadline fires once")
    check(!clock.tick(now: now.addingTimeInterval(7201)), "wake has no duplicate reminder")
    clock.show()
    check(clock.presenting && clock.deadline == nil, "manual preview clears pending deadline")
    clock.start(now: now)
    check(!clock.presenting && !clock.paused, "dismiss resets presentation state")
    print("\(checks) checks passed")
}

if CommandLine.arguments.contains("--self-test") {
    selfTest()
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
