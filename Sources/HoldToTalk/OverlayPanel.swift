import AppKit

/// Small floating "listening…" bubble at the bottom of the screen with live text.
final class OverlayPanel {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private let dot = NSView()

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let bg = NSVisualEffectView()
        bg.material = .hudWindow
        bg.state = .active
        bg.blendingMode = .behindWindow
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 16
        bg.layer?.masksToBounds = true
        panel.contentView = bg

        dot.wantsLayer = true
        dot.layer?.cornerRadius = 6
        dot.translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingHead
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false

        bg.addSubview(dot)
        bg.addSubview(label)
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 18),
            dot.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -18),
            label.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
        ])
    }

    func showListening() {
        dot.layer?.backgroundColor = NSColor.systemRed.cgColor
        label.stringValue = "Говорите…"
        position()
        panel.orderFrontRegardless()
    }

    func update(text: String) {
        guard panel.isVisible, !text.isEmpty else { return }
        label.stringValue = text
    }

    func showProcessing() {
        dot.layer?.backgroundColor = NSColor.systemOrange.cgColor
    }

    func showMessage(_ text: String) {
        dot.layer?.backgroundColor = NSColor.systemYellow.cgColor
        label.stringValue = text
        position()
        panel.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.hide() }
    }

    func hide() { panel.orderOut(nil) }

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: vf.midX - size.width / 2, y: vf.minY + 80))
    }
}
