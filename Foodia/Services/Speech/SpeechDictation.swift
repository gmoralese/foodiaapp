import AVFoundation
import Speech

/// Dictado por voz para el contexto del análisis. Usa SFSpeechRecognizer con
/// reconocimiento on-device cuando el equipo lo soporta (no requiere Apple
/// Intelligence); si no, el framework cae a los servidores de Apple.
@Observable
final class SpeechDictation {
    enum State: Equatable {
        case idle
        case recording
        case denied
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var transcript: String = ""

    private let engine = DictationEngine()

    var isAvailable: Bool {
        DictationEngine.isRecognizerAvailable
    }

    func toggle() {
        if state == .recording {
            stop()
        } else {
            Task { await start() }
        }
    }

    func start() async {
        transcript = ""

        let speechStatus = await withCheckedContinuation { continuation in
            // El handler llega en una cola arbitraria: @Sendable explícito para
            // que Swift no lo aísle al MainActor.
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            state = .denied
            return
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            state = .denied
            return
        }

        let started = engine.start { [weak self] text, isFinal in
            // Llega en la cola del reconocedor: salto explícito al MainActor.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !text.isEmpty {
                    self.transcript = text
                }
                if isFinal {
                    self.stop()
                }
            }
        }
        state = started
            ? .recording
            : .failed(String(localized: "El reconocimiento de voz no está disponible."))
    }

    func stop() {
        engine.stop()
        if state == .recording {
            state = .idle
        }
    }
}

/// Dueño del motor de audio y el reconocedor. Vive FUERA del MainActor:
/// los closures que se forman acá adentro quedan nonisolated, así el sistema
/// puede invocarlos en sus colas sin violar el aislamiento (era la causa del
/// crash `_dispatch_assert_queue_fail`).
private nonisolated final class DictationEngine: @unchecked Sendable {
    static var isRecognizerAvailable: Bool {
        SFSpeechRecognizer(locale: Locale.current)?.isAvailable ?? false
    }

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Devuelve false si el reconocedor no está disponible o el audio falló.
    /// `onTranscript(texto, esFinal)` puede llegar en cualquier cola.
    func start(onTranscript: @escaping @Sendable (String, Bool) -> Void) -> Bool {
        let recognizer = SFSpeechRecognizer(locale: Locale.current)
        guard let recognizer, recognizer.isAvailable else { return false }
        self.recognizer = recognizer

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()

            task = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    onTranscript(result.bestTranscription.formattedString, result.isFinal)
                }
                if error != nil {
                    onTranscript("", true)
                }
            }
            return true
        } catch {
            stop()
            return false
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
