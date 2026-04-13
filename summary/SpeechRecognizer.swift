import Speech
import AVFoundation

@Observable
class SpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var errorMessage: String?
    var audioLevel: Float = 0  // 0.0–1.0, for waveform visualization

    var onAutoStop: (() -> Void)?  // called when silence auto-stops recording

    /// URL of the WAV file recorded during the last session. Nil if recording failed or not started.
    private(set) var lastRecordingFileURL: URL?

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: .current)
    private var audioFile: AVAudioFile?

    private var silenceTimer: Timer?
    private var hasReceivedSpeech = false
    private let silenceDuration: TimeInterval = 2.0

    // Throttle: update UI every ~3 buffers (~15 fps at 44.1 kHz / 1024 frames)
    private var bufferCount = 0

    func startRecording() async {
        guard await requestPermissions() else { return }
        do {
            transcript = ""
            hasReceivedSpeech = false
            lastRecordingFileURL = nil
            silenceTimer?.invalidate()
            silenceTimer = nil
            try beginRecognition()
            isRecording = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stops recording and returns the live SFSpeechRecognizer transcript.
    /// The audio file is available at `lastRecordingFileURL` for Whisper post-processing.
    func stopRecording() -> String {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
        audioFile = nil  // closes and flushes the WAV file
        isRecording = false
        audioLevel = 0
        let result = transcript
        transcript = ""
        return result
    }

    private func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            errorMessage = "Speech recognition access denied."
            return false
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            errorMessage = "Microphone access denied."
            return false
        }
        return true
    }

    private func beginRecognition() throws {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, _ in
            if let result {
                DispatchQueue.main.async {
                    self?.transcript = result.bestTranscription.formattedString
                    if !result.bestTranscription.formattedString.isEmpty {
                        self?.hasReceivedSpeech = true
                    }
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            throw NSError(
                domain: "SpeechRecognizer", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No audio input available. Speech recording requires a microphone (not supported in Simulator)."]
            )
        }

        // Record to a WAV file for Whisper post-processing
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileURL = cacheDir.appendingPathComponent("voice_\(Int(Date().timeIntervalSince1970)).wav")
        if let file = try? AVAudioFile(forWriting: fileURL, settings: format.settings) {
            audioFile = file
            lastRecordingFileURL = fileURL
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            try? self?.audioFile?.write(from: buffer)
            self?.processAudioLevel(buffer: buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    // Called on the audio thread — dispatches to main for all state mutation.
    private func processAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        // RMS amplitude
        var sumSquares: Float = 0
        for i in 0..<frameLength { sumSquares += channelData[i] * channelData[i] }
        let rms = sqrt(sumSquares / Float(frameLength))
        let normalized = min(rms * 18, 1.0)

        bufferCount += 1
        let updateUI = bufferCount % 3 == 0  // ~15 fps

        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRecording else { return }

            // Silence detection — only after first speech received
            if self.hasReceivedSpeech {
                if normalized < 0.03 {
                    if self.silenceTimer == nil {
                        self.silenceTimer = Timer.scheduledTimer(
                            withTimeInterval: self.silenceDuration,
                            repeats: false
                        ) { [weak self] _ in
                            self?.onAutoStop?()
                        }
                    }
                } else {
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = nil
                }
            }

            if updateUI {
                self.audioLevel = normalized
            }
        }
    }
}
