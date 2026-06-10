import AVFoundation
import Combine
import Foundation
import OSLog
import Speech

@MainActor
final class SpeechTranscriber: ObservableObject {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.blizzard1311.yiji",
        category: "SpeechTranscriber"
    )

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

    @Published var authorizationStatus: AuthorizationStatus = .unknown
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var errorMessage: String?

    var onTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isFinishingRecognition = false
    private var autoStopTask: Task<Void, Never>?
    private var maxRecordingTask: Task<Void, Never>?
    private let initialSpeechTimeout: TimeInterval = 6
    private let trailingSilenceTimeout: TimeInterval = 1.4
    private let maxRecordingDuration: TimeInterval = 20

    func refreshAuthorizationStatus() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let microphoneStatus = microphoneAuthorizationStatus()

        if speechStatus == .authorized && microphoneStatus == .authorized {
            authorizationStatus = .granted
        } else if speechStatus == .notDetermined || microphoneStatus == .notDetermined {
            authorizationStatus = .unknown
        } else {
            authorizationStatus = .denied
        }
    }

    func startRecording() {
        errorMessage = nil

        if isRunningInSimulator {
            authorizationStatus = .denied
            errorMessage = "模拟器不支持稳定的语音听写录入，请改用真机测试语音，或先直接输入文字。"
            isRecording = false
            return
        }

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let microphoneStatus = microphoneAuthorizationStatus()

        if speechStatus == .notDetermined || microphoneStatus == .notDetermined {
            requestInitialPermissions(
                currentSpeechStatus: speechStatus,
                currentMicrophoneStatus: microphoneStatus
            )
            return
        }

        let speechAuthorized = speechStatus == .authorized
        let microphoneAuthorized = microphoneStatus == .authorized

        guard speechAuthorized && microphoneAuthorized else {
            authorizationStatus = .denied
            errorMessage = "没有语音识别或麦克风权限，请到系统设置里开启。"
            return
        }

        beginRecordingSession()
    }

    func stopRecording() {
        finishRecordingSession()
    }

    func resetTranscript() {
        transcript = ""
        errorMessage = nil
        onTranscript?("")
    }

    private func beginRecordingSession() {
        authorizationStatus = .granted

        guard let speechRecognizer else {
            errorMessage = "当前设备不支持中文语音识别。"
            logger.error("speech recognizer unavailable for zh-CN locale")
            return
        }

        guard speechRecognizer.isAvailable else {
            errorMessage = "语音识别当前不可用，请稍后再试。"
            logger.error("speech recognizer is not available")
            return
        }

        cancelRecordingSession()

        transcript = ""
        onTranscript?("")

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "无法启动录音会话：\(error.localizedDescription)"
            logger.error("audio session activation failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        let inputNode = audioEngine.inputNode
        guard let recordingFormat = validRecordingFormat(for: inputNode) else {
            errorMessage = "当前设备没有可用的麦克风输入。模拟器上语音听写可能不可用，请改用真机或直接输入文字。"
            logger.error("no valid recording format available from input node")
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                errorMessage = "当前设备没有可用的麦克风输入，且无法关闭录音会话：\(error.localizedDescription)"
                logger.error("audio session deactivation after invalid format failed: \(error.localizedDescription, privacy: .public)")
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
                    self.scheduleAutoStop(after: self.trailingSilenceTimeout)
                    if result.isFinal {
                        self.onFinalTranscript?(self.transcript)
                        self.completeRecognitionSession()
                        return
                    }
                }

                if let error {
                    let nsError = error as NSError
                    if self.isRecognitionCancellation(nsError) {
                        self.completeRecognitionSession()
                        return
                    }

                    if self.isNoSpeechDetected(nsError) {
                        self.errorMessage = "没有识别到语音，请靠近麦克风后重试。"
                    } else {
                        self.errorMessage = "语音识别失败：\(error.localizedDescription)"
                        self.logger.error(
                            "recognition task failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code) description=\(error.localizedDescription, privacy: .public)"
                        )
                    }
                    self.completeRecognitionSession()
                }
            }
        }

        installRecognitionTap(
            on: inputNode,
            format: recordingFormat,
            recognitionRequest: recognitionRequest
        )

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            scheduleAutoStop(after: initialSpeechTimeout)
            scheduleMaxRecordingStop()
        } catch {
            errorMessage = "无法开始录音：\(error.localizedDescription)"
            logger.error("audio engine start failed: \(error.localizedDescription, privacy: .public)")
            stopRecording()
        }
    }

    private func requestInitialPermissions(
        currentSpeechStatus: SFSpeechRecognizerAuthorizationStatus,
        currentMicrophoneStatus: AVAuthorizationStatus
    ) {
        Task { [weak self] in
            guard let self else { return }

            let speechStatus = await requestSpeechAuthorizationStatus(currentStatus: currentSpeechStatus)
            let microphoneAuthorized = await requestMicrophoneAccess(currentStatus: currentMicrophoneStatus)
            self.handleInitialPermissionResult(
                speechStatus: speechStatus,
                microphoneAuthorized: microphoneAuthorized
            )
        }
    }

    private func handleInitialPermissionResult(
        speechStatus: SFSpeechRecognizerAuthorizationStatus,
        microphoneAuthorized: Bool
    ) {
        refreshAuthorizationStatus()
        let speechAuthorized = speechStatus == .authorized

        guard speechAuthorized && microphoneAuthorized else {
            authorizationStatus = .denied
            errorMessage = "没有语音识别或麦克风权限，请到系统设置里开启。"
            isRecording = false
            return
        }

        errorMessage = nil
        beginRecordingSession()
    }

    private func finishRecordingSession() {
        guard isRecording || recognitionTask != nil || recognitionRequest != nil else {
            isRecording = false
            return
        }

        autoStopTask?.cancel()
        autoStopTask = nil
        maxRecordingTask?.cancel()
        maxRecordingTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isRecording = false
        isFinishingRecognition = true
    }

    private func cancelRecordingSession() {
        autoStopTask?.cancel()
        autoStopTask = nil
        maxRecordingTask?.cancel()
        maxRecordingTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        completeRecognitionSession()
    }

    private func completeRecognitionSession() {
        autoStopTask?.cancel()
        autoStopTask = nil
        maxRecordingTask?.cancel()
        maxRecordingTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        isFinishingRecognition = false
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = errorMessage ?? "无法结束录音会话：\(error.localizedDescription)"
            logger.error("audio session deactivation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func isRecognitionCancellation(_ error: NSError) -> Bool {
        error.localizedDescription.localizedCaseInsensitiveContains("canceled")
    }

    private func isNoSpeechDetected(_ error: NSError) -> Bool {
        error.localizedDescription.localizedCaseInsensitiveContains("no speech detected")
    }

    private func microphoneAuthorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
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

    private func scheduleAutoStop(after interval: TimeInterval) {
        autoStopTask?.cancel()
        autoStopTask = Task { [weak self] in
            let duration = UInt64(interval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isRecording else { return }
                self.finishRecordingSession()
            }
        }
    }

    private func scheduleMaxRecordingStop() {
        maxRecordingTask?.cancel()
        let duration = UInt64(maxRecordingDuration * 1_000_000_000)
        maxRecordingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isRecording else { return }
                self.finishRecordingSession()
            }
        }
    }
}

private func requestSpeechAuthorizationStatus(
    currentStatus: SFSpeechRecognizerAuthorizationStatus
) async -> SFSpeechRecognizerAuthorizationStatus {
    guard currentStatus == .notDetermined else {
        return currentStatus
    }

    return await withCheckedContinuation(isolation: nil) { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status)
        }
    }
}

private func requestMicrophoneAccess(currentStatus: AVAuthorizationStatus) async -> Bool {
    switch currentStatus {
    case .authorized:
        return true
    case .denied, .restricted:
        return false
    case .notDetermined:
        return await withCheckedContinuation(isolation: nil) { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    @unknown default:
        return false
    }
}

private func installRecognitionTap(
    on inputNode: AVAudioInputNode,
    format: AVAudioFormat,
    recognitionRequest: SFSpeechAudioBufferRecognitionRequest
) {
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(
        onBus: 0,
        bufferSize: 1024,
        format: format,
        block: makeRecognitionTap(recognitionRequest: recognitionRequest)
    )
}

private func makeRecognitionTap(
    recognitionRequest: SFSpeechAudioBufferRecognitionRequest
) -> AVAudioNodeTapBlock {
    { buffer, _ in
        recognitionRequest.append(buffer)
    }
}
