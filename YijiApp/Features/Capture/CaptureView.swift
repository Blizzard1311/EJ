import SwiftUI
import UIKit
import YijiCore

struct CaptureView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openURL) private var openURL
    @State private var pinnedVoiceText = ""

    var body: some View {
        ZStack {
            screenBackground

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 72)
                        headerHint
                        Spacer(minLength: 64)
                        microphoneStage
                        Spacer(minLength: 72)
                        footerHint
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height - 12, alignment: .center)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationTitle("记")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            syncPinnedVoiceText(from: appModel.captureText)
        }
        .onChange(of: appModel.captureText) { newValue in
            syncPinnedVoiceText(from: newValue)
        }
    }

    private var screenBackground: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.93, green: 0.95, blue: 0.99))
                .frame(width: 360, height: 360)
                .blur(radius: 52)
                .offset(x: 130, y: -250)

            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 0.99),
                    Color(red: 0.985, green: 0.985, blue: 0.99)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var headerHint: some View {
        Text("记录、提醒、提问，都从这一句开始")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var microphoneStage: some View {
        VStack(spacing: 18) {
            Button(action: toggleMicrophone) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.80))
                        .frame(width: 214, height: 214)
                        .shadow(color: Color.black.opacity(0.04), radius: 28, y: 12)

                    Circle()
                        .stroke(
                            appModel.speech.isRecording ? Color.red.opacity(0.24) : Color(red: 0.69, green: 0.79, blue: 0.94).opacity(0.38),
                            lineWidth: 18
                        )
                        .frame(width: 168, height: 168)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: appModel.speech.isRecording
                                    ? [Color(red: 0.96, green: 0.40, blue: 0.37), Color(red: 0.79, green: 0.18, blue: 0.18)]
                                    : [Color(red: 0.64, green: 0.75, blue: 0.93), Color(red: 0.56, green: 0.68, blue: 0.89)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 108, height: 108)
                        .shadow(
                            color: appModel.speech.isRecording ? Color.red.opacity(0.14) : Color(red: 0.69, green: 0.79, blue: 0.94).opacity(0.18),
                            radius: 10,
                            y: 6
                        )

                    Image(systemName: appModel.speech.isRecording ? "waveform.circle.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(appModel.speech.isRecording ? "结束录音" : "开始录音")

            if !appModel.speech.isRecording {
                Text("点一下开始")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if shouldShowVoiceFeedback {
                voiceFeedbackPanel
            }

            if appModel.speech.authorizationStatus == .denied {
                Button("前往系统设置开启语音权限") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .font(.footnote.weight(.medium))
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var footerHint: some View {
        VStack(spacing: 8) {
            Text("例如：")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("我的护照在哪 / 今晚十点提醒我交电费 / 下周有哪些商务安排")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.84))
        )
    }

    private var voiceFeedbackPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: appModel.speech.isRecording ? "waveform" : "text.bubble")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appModel.speech.isRecording ? .red : .blue)

                Text(appModel.speech.isRecording ? "实时识别" : "解析结果")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            if let visibleVoiceText {
                Text(visibleVoiceText)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if appModel.speech.isRecording {
                Text("正在听，你说的话会先转成文字。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !voiceUnderstandingRows.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(voiceUnderstandingRows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: 10) {
                            Text(row.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 52, alignment: .leading)

                            Text(row.value)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            if let feedbackStatusMessage {
                Divider()

                Label(feedbackStatusMessage, systemImage: feedbackStatusIcon)
                    .font(.footnote)
                    .foregroundStyle(feedbackStatusColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.90))
        )
    }

    private var shouldShowVoiceFeedback: Bool {
        appModel.speech.isRecording
            || visibleVoiceText != nil
            || feedbackStatusMessage != nil
    }

    private var visibleVoiceText: String? {
        let liveText = appModel.captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !liveText.isEmpty {
            return liveText
        }

        let transcript = appModel.speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !transcript.isEmpty {
            return transcript
        }

        let pinnedText = pinnedVoiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        return pinnedText.isEmpty ? nil : pinnedText
    }

    private var voiceUnderstandingRows: [(label: String, value: String)] {
        guard let visibleVoiceText else {
            return []
        }

        if SearchIntentClassifier.isSearchQuery(visibleVoiceText) {
            return [
                ("理解为", "提问"),
                ("下一步", "会到“录”里显示相关结果")
            ]
        }

        guard let parsed = appModel.preview(for: visibleVoiceText) else {
            return []
        }

        var rows: [(label: String, value: String)] = [
            ("理解为", parsed.record.displayCategoryName)
        ]

        if let warning = parsed.warnings.first {
            rows.append(("提醒", warning))
            return rows
        }

        if let reminder = parsed.reminder {
            rows.append(("提醒时间", YijiDateFormatter.dateTimeFormatter.string(from: reminder.remindAt)))
        } else if let objectName = parsed.record.objectName, let location = parsed.record.location {
            rows.append(("位置", "\(objectName) 在 \(location)"))
        } else if let eventTime = parsed.record.eventTime {
            rows.append(("时间", eventTime.displayText()))
        }

        if !parsed.record.sliceCategoryNames.isEmpty {
            rows.append(("分类", parsed.record.sliceCategoryNames.joined(separator: " / ")))
        }

        return Array(rows.prefix(3))
    }

    private var feedbackStatusMessage: String? {
        if let errorMessage = appModel.speech.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !errorMessage.isEmpty {
            return errorMessage
        }

        guard !appModel.speech.isRecording,
              let statusMessage = appModel.statusMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !statusMessage.isEmpty,
              visibleVoiceText != nil else {
            return nil
        }

        return statusMessage
    }

    private var feedbackStatusIcon: String {
        appModel.speech.errorMessage == nil ? "checkmark.circle" : "exclamationmark.circle"
    }

    private var feedbackStatusColor: Color {
        appModel.speech.errorMessage == nil ? .green : .red
    }

    private func syncPinnedVoiceText(from text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pinnedVoiceText = trimmed
    }

    private func toggleMicrophone() {
        appModel.draftSource = .voice
        if appModel.speech.isRecording {
            appModel.stopVoiceCapture()
        } else {
            appModel.startVoiceCapture()
        }
    }
}

#Preview("记页面 - iPhone 16 Pro") {
    PreviewSupport.canvas {
        NavigationStack {
            CaptureView()
        }
    }
}

#Preview("记页面 - Dark") {
    PreviewSupport.canvas(colorScheme: .dark) {
        NavigationStack {
            CaptureView()
        }
    }
}

#Preview("一句话页面 - 权限未开启") {
    PreviewSupport.canvas(model: PreviewSupport.voiceDeniedAppModel(), device: "iPhone SE (3rd generation)") {
        NavigationStack {
            CaptureView()
        }
    }
}
