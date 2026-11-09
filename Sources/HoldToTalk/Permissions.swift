import AppKit
import AVFoundation
import Speech
import ApplicationServices

final class Permissions: ObservableObject {
    @Published var microphone = false
    @Published var speech = false
    @Published var accessibility = false

    var allGranted: Bool { microphone && speech && accessibility }

    func refresh() {
        microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        speech = SFSpeechRecognizer.authorizationStatus() == .authorized
        accessibility = AXIsProcessTrusted()
    }

    func requestAll() {
        requestMicrophone()
        requestSpeech()
        requestAccessibility()
    }

    func requestMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in DispatchQueue.main.async { self.refresh() } }
        case .authorized: break
        default: openSettings("Privacy_Microphone")
        }
    }

    func requestSpeech() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { _ in DispatchQueue.main.async { self.refresh() } }
        case .authorized: break
        default: openSettings("Privacy_SpeechRecognition")
        }
    }

    func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opts) {
            openSettings("Privacy_Accessibility")
        }
    }

    func openSettings(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
