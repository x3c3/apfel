// ============================================================================
// STTManager.swift — On-device speech-to-text via SFSpeechRecognizer
// Part of apfel GUI. On-device transcription when available.
// ============================================================================

import Speech
import AVFoundation

@Observable
@MainActor
class STTManager {
    var isListening = false
    var transcript = ""
    var errorMessage: String?

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    /// Check if speech recognition is available and authorized.
    var isAvailable: Bool {
        guard let recognizer else { return false }
        return recognizer.isAvailable && SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    /// Request microphone and speech recognition permissions.
    func requestPermissions() async -> Bool {
        // Check current status first — avoid the callback entirely if already decided
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        if currentStatus == .authorized {
            printStderr("STT: already authorized")
            return true
        }
        if currentStatus == .denied || currentStatus == .restricted {
            errorMessage = "Speech recognition denied. Enable in System Settings → Privacy & Security → Speech Recognition."
            printStderr("STT: authorization denied (status: \(currentStatus.rawValue))")
            return false
        }

        // Status is .notDetermined — need to request
        // Use a nonisolated callback to avoid the MainActor dispatch_assert crash
        let authorized = await withUnsafeContinuation { (continuation: UnsafeContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        if !authorized {
            errorMessage = "Speech recognition not authorized. Enable in System Settings → Privacy & Security → Speech Recognition."
            printStderr("STT: authorization denied after request")
        } else {
            printStderr("STT: authorized")
        }
        return authorized
    }

    /// Start listening to microphone and transcribing.
    func startListening() {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer not available for this language"
            printStderr("STT: recognizer not available")
            return
        }

        transcript = ""
        errorMessage = nil

        do {
            let engine = AVAudioEngine()
            self.audioEngine = engine

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true

            // Prefer on-device recognition if available
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
                printStderr("STT: using on-device recognition")
            } else {
                printStderr("STT: on-device not available, using server")
            }

            self.recognitionRequest = request

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if let error {
                        printStderr("STT: recognition error: \(error.localizedDescription)")
                    }
                }
            }

            // Install audio tap
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
                errorMessage = "No microphone input available"
                printStderr("STT: invalid audio format (no mic?)")
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            engine.prepare()
            try engine.start()
            isListening = true
            printStderr("STT: listening started")

        } catch {
            errorMessage = "Failed to start listening: \(error.localizedDescription)"
            printStderr("STT: start error: \(error)")
            cleanup()
        }
    }

    /// Stop listening and return the final transcript.
    func stopListening() -> String {
        printStderr("STT: stopping, transcript: \"\(transcript)\"")
        cleanup()
        return transcript
    }

    private func cleanup() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }
}
