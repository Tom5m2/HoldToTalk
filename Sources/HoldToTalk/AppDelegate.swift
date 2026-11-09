import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let permissions = Permissions()
    private let ui = UIState()
    private let speech = SpeechEngine()
    private let overlay = OverlayPanel()
    private lazy var monitor = HotkeyMonitor(hotkey: settings.hotkey)

    private var statusItem: NSStatusItem!
    private var hotkeyMenuItem: NSMenuItem!
    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private var isRecording = false
    private var pressedAt = Date()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        monitor.onPress = { [weak self] in self?.beginDictation() }
        monitor.onRelease = { [weak self] in self?.endDictation() }
        monitor.onInterrupt = { [weak self] in self?.cancelDictation() }

        settings.$hotkey
            .sink { [weak self] hk in
                self?.monitor.hotkey = hk
                self?.hotkeyMenuItem?.title = "Клавиша: \(hk.name)"
            }
            .store(in: &cancellables)

        speech.onPartial = { [weak self] text in
            guard let self, self.settings.showOverlay else { return }
            self.overlay.update(text: text)
        }

        permissions.refresh()
        if !permissions.allGranted {
            permissions.requestAll()
            showSettings()
        }
        monitor.start()

        // Keep checking until permissions are granted (the user flips switches in System Settings).
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.permissions.refresh()
            if !self.monitor.isRunning { self.monitor.start() }
            self.updateIcon()
        }
        updateIcon()
    }

    // MARK: Dictation

    private func beginDictation() {
        guard !isRecording else { return }
        permissions.refresh()
        guard permissions.microphone, permissions.speech else {
            overlay.showMessage("Нужны разрешения на микрофон и распознавание речи")
            showSettings()
            return
        }
        do {
            try speech.start(localeID: settings.localeID, onDevice: settings.onDevice)
        } catch {
            overlay.showMessage(error.localizedDescription)
            return
        }
        isRecording = true
        pressedAt = Date()
        if settings.playSounds { NSSound(named: "Tink")?.play() }
        if settings.showOverlay { overlay.showListening() }
        updateIcon()
    }

    private func endDictation() {
        guard isRecording else { return }
        isRecording = false
        updateIcon()

        // A very short tap is probably accidental.
        if Date().timeIntervalSince(pressedAt) < 0.3 {
            speech.cancel()
            overlay.hide()
            return
        }
        if settings.playSounds { NSSound(named: "Pop")?.play() }
        overlay.showProcessing()
        speech.stop { [weak self] text in
            guard let self else { return }
            self.overlay.hide()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            TextInserter.insert(trimmed + (self.settings.addTrailingSpace ? " " : ""))
        }
    }

    private func cancelDictation() {
        guard isRecording else { return }
        isRecording = false
        speech.cancel()
        overlay.hide()
        updateIcon()
    }

    // MARK: Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        hotkeyMenuItem = NSMenuItem(title: "Клавиша: \(settings.hotkey.name)", action: nil, keyEquivalent: "")
        hotkeyMenuItem.isEnabled = false
        menu.addItem(hotkeyMenuItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Настройки…", action: #selector(openSettingsAction), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let symbol: String
        let tint: NSColor?
        if isRecording {
            symbol = "mic.fill"; tint = .systemRed
        } else if !permissions.allGranted || !monitor.isRunning {
            symbol = "mic.slash"; tint = nil
        } else {
            symbol = "mic"; tint = nil
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "HoldToTalk")
        image?.isTemplate = tint == nil
        button.image = image
        button.contentTintColor = tint
    }

    @objc private func openSettingsAction() { showSettings() }

    private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(
                settings: settings, permissions: permissions, ui: ui,
                startCapture: { [weak self] in self?.startHotkeyCapture() },
                cancelCapture: { [weak self] in self?.stopHotkeyCapture() }
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "HoldToTalk — настройки"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func startHotkeyCapture() {
        ui.isCapturingHotkey = true
        monitor.captureHandler = { [weak self] hk in
            guard let self else { return }
            if let hk { self.settings.hotkey = hk }
            self.ui.isCapturingHotkey = false
        }
    }

    private func stopHotkeyCapture() {
        monitor.captureHandler = nil
        ui.isCapturingHotkey = false
    }
}
