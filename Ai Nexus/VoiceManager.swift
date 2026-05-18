import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class VoiceManager: ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var error: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var isTapInstalled = false

    func requestPermissions() async -> Bool {
        print("VoiceManager: Requesting permissions...")
        
        let micAuthorized = await withCheckedContinuation { continuation in
            #if os(iOS)
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    print("VoiceManager: Mic permission (iOS 17+): \(granted)")
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    print("VoiceManager: Mic permission (iOS): \(granted)")
                    continuation.resume(returning: granted)
                }
            }
            #else
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            print("VoiceManager: Current mic status (macOS): \(status.rawValue)")
            switch status {
            case .authorized:
                continuation.resume(returning: true)
            case .notDetermined:
                print("VoiceManager: Requesting mic access on macOS...")
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    print("VoiceManager: Mic access granted: \(granted)")
                    continuation.resume(returning: granted)
                }
            default:
                continuation.resume(returning: false)
            }
            #endif
        }
        
        guard micAuthorized else {
            print("VoiceManager: Mic permission denied.")
            return false
        }
        
        let speechAuthorized = await withCheckedContinuation { continuation in
            print("VoiceManager: Requesting speech recognition authorization...")
            SFSpeechRecognizer.requestAuthorization { status in
                print("VoiceManager: Speech status: \(status.rawValue)")
                continuation.resume(returning: status == .authorized)
            }
        }
        
        return speechAuthorized
    }

    func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            self.error = "Speech recognizer is not available."
            return
        }

        stopRecording() // Ensure any previous task is stopped

        do {
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            let engine = AVAudioEngine()
            self.audioEngine = engine
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            isTapInstalled = true

            engine.prepare()
            try engine.start()

            isRecording = true
            transcript = ""

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if error != nil || (result?.isFinal ?? false) {
                    self.stopRecording()
                }
            }
        } catch {
            self.error = "Could not start audio engine: \(error.localizedDescription)"
            stopRecording()
        }
    }

    func stopRecording() {
        audioEngine?.stop()
        if isTapInstalled {
            audioEngine?.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecording = false
    }
}
