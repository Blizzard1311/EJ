import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class SpeechTranscriber {
    enum AuthorizationStatus: String {
        case unknown
        case granted
        case denied

        var displayName: String {
            switch self {
            case .unknown:
                "未请求"
            case .granted:
                "已授权"
            case .denied:
                "未授权"
            }
        }
    }

    var authorizationStatus: AuthorizationStatus = .unknown
    var isRecording = false
    var transcript = ""
    var errorMessage: String?

    var onTranscript: ((String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func refreshAuthorizationStatus() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let microphoneStatus = AVAudioApplication.shared.recordPermission

        if speechStatus == .authorized && microphoneStatus == .granted {
            authorizationStatus = .granted
        } else if speechStatus == .notDetermined || microphoneStatus == .undetermined {
            authorizationStatus = .unknown
        } else {
            authorizationStatus = .denied
        }
    }

    func startRecording() async {
        errorMessage = nil

        if isRunningInSimulator {
            authorizationStatus = .denied
            errorMessage = "模拟器不支持稳定的语音听写录入，请改用真机测试语音，或先直接输入文字。"
            isRecording = false
            return
        }

        let speechAuthorized = await requestSpeechAuthorizationIfNeeded(promptIfUnknown: true)
        let microphoneAuthorized = await requestMicrophoneAuthorizationIfNeeded(promptIfUnknown: true)

        guard speechAuthorized && microphoneAuthorized else {
            authorizationStatus = .denied
            errorMessage = "没有语音识别或麦克风权限，请到系统设置里开启。"
            return
        }

        authorizationStatus = .granted

        guard let speechRecognizer else {
            errorMessage = "当前设备不支持中文语音识别。"
            return
        }

        guard speechRecognizer.isAvailable else {
            errorMessage = "语音识别当前不可用，请稍后再试。"
            return
        }

        stopRecording()

        transcript = ""
        onTranscript?("")

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "无法启动录音会话：\(error.localizedDescription)"
            return
        }

        let inputNode = audioEngine.inputNode
        guard let recordingFormat = validRecordingFormat(for: inputNode) else {
            errorMessage = "当前设备没有可用的麦克风输入。模拟器上语音听写可能不可用，请改用真机或直接输入文字。"
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                errorMessage = "当前设备没有可用的麦克风输入，且无法关闭录音会话：\(error.localizedDescription)"
            }
            return
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        self.recognitionRequest = recognitionRequest

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.onTranscript?(self.transcript)
                    if result.isFinal {
                        self.stopRecording()
                    }
                }

                if let error {
                    self.errorMessage = "语音识别失败：\(error.localizedDescription)"
                    self.stopRecording()
                }
            }
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "无法开始录音：\(error.localizedDescription)"
            stopRecording()
        }
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = errorMessage ?? "无法结束录音会话：\(error.localizedDescription)"
        }
    }

    func resetTranscript() {
        transcript = ""
        errorMessage = nil
        onTranscript?("")
    }

    private func requestSpeechAuthorizationIfNeeded(promptIfUnknown: Bool) async -> Bool {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()

        if !promptIfUnknown && currentStatus == .notDetermined {
            return false
        }

        let status: SFSpeechRecognizerAuthorizationStatus
        if currentStatus == .notDetermined {
            status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
        } else {
            status = currentStatus
        }

        return status == .authorized
    }

    private func requestMicrophoneAuthorizationIfNeeded(promptIfUnknown: Bool) async -> Bool {
        let permission = AVAudioApplication.shared.recordPermission

        if !promptIfUnknown && permission == .undetermined {
            return false
        }

        switch permission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func validRecordingFormat(for inputNode: AVAudioInputNode) -> AVAudioFormat? {
        let inputFormat = inputNode.inputFormat(forBus: 0)
        if isValidAudioFormat(inputFormat) {
            return inputFormat
        }

        let outputFormat = inputNode.outputFormat(forBus: 0)
        if isValidAudioFormat(outputFormat) {
            return outputFormat
        }

        return nil
    }

    private func isValidAudioFormat(_ format: AVAudioFormat) -> Bool {
        format.sampleRate > 0 && format.channelCount > 0
    }

    private var isRunningInSimulator: Bool {
#if targetEnvironment(simulator)
        true
#else
        false
#endif
    }
}
