import AVFoundation
import Speech

enum SpeechError: LocalizedError {
    case unavailable(String)
    case noMicrophone

    var errorDescription: String? {
        switch self {
        case .unavailable(let id): return "Распознавание для языка \(id) сейчас недоступно"
        case .noMicrophone: return "Микрофон не найден или нет доступа"
        }
    }
}

/// Records from the microphone while the key is held and transcribes with Apple's Speech framework.
final class SpeechEngine {
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var latestText = ""
    private var finishHandler: ((String) -> Void)?
    private var session = 0

    var onPartial: ((String) -> Void)?

    func start(localeID: String, onDevice: Bool) throws {
        flushPending()
        cancel()

        if recognizer?.locale.identifier != localeID {
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID))
        }
        guard let recognizer, recognizer.isAvailable else { throw SpeechError.unavailable(localeID) }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.addsPunctuation = true
        req.taskHint = .dictation
        if onDevice && recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { throw SpeechError.noMicrophone }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }

        session += 1
        let current = session
        latestText = ""
        request = req
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.session == current else { return }
                if let result {
                    self.latestText = result.bestTranscription.formattedString
                    self.onPartial?(self.latestText)
                    if result.isFinal { self.flushPending() }
                }
                if error != nil { self.flushPending() }
            }
        }
    }

    /// Stop recording and deliver the final text (or whatever we have after a timeout).
    func stop(completion: @escaping (String) -> Void) {
        finishHandler = completion
        stopAudio()
        request?.endAudio()
        let current = session
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self, self.session == current else { return }
            self.flushPending()
        }
    }

    func cancel() {
        stopAudio()
        task?.cancel()
        task = nil
        request = nil
        finishHandler = nil
        session += 1
    }

    private func stopAudio() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func flushPending() {
        guard let handler = finishHandler else { return }
        finishHandler = nil
        let text = latestText
        task?.finish()
        task = nil
        request = nil
        handler(text)
    }
}
