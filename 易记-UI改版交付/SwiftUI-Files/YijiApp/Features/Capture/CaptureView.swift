import SwiftUI
import UIKit
import YijiCore

struct CaptureView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openURL) private var openURL
    @State private var pinnedVoiceText = ""
    @State private var isPressingMicrophone = false

    var body: some View {
        ZStack {
            screenBackground

            GeometryReader { proxy in
                let topInset = proxy.safeAreaInsets.top
                let bottomInset = proxy.safeAreaInsets.bottom
                let availableHeight = max(proxy.size.height - topInset - bottomInset, 0)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Text("易记")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 96)
                        microphoneStage
                        Spacer(minLength: 64)

                        Label("记录优先保存在本机", systemImage: "lock")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: availableHeight - 12, alignment: .center)
                    .padding(.horizontal, 28)
                    .padding(.top, 24)
                    .padding(.bottom, bottomInset + 24)
                }
            }
        }
        .onAppear {
            syncPinnedVoiceText(from: appModel.captureText)
        }
        .onChange(of: appModel.captureText) { newValue in
            syncPinnedVoiceText(from: newValue)
        }
    }

    private var screenBackground: some View {
        AppTheme.canvas
        .ignoresSafeArea()
    }

    private var microphoneStage: some View {
        VStack(spacing: 18) {
            Text("想记什么，直接说出来")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)

            microphoneButton
                .accessibilityLabel(appModel.speech.isRecording ? "松开结束录音" : "按住开始录音")

            if !appModel.speech.isRecording {
                Text(visibleVoiceText == nil ? "按住说话" : "编辑后保存")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if let restingStatusMessage {
                Label(restingStatusMessage, systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.12))
                    )
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
                .foregroundStyle(AppTheme.accent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var microphoneButton: some View {
        ZStack {
            Circle()
                .fill(AppTheme.surfaceMuted)
                .frame(width: 232, height: 232)

            Circle()
                .stroke(
                    appModel.speech.isRecording ? Color.red.opacity(0.20) : AppTheme.line,
                    lineWidth: 1
                )
                .frame(width: 176, height: 176)

            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(appModel.speech.isRecording ? Color.red.opacity(0.88) : AppTheme.accent)
                .frame(width: 120, height: 120)
                .shadow(
                    color: (appModel.speech.isRecording ? Color.red : AppTheme.accent).opacity(0.18),
                    radius: 16,
                    y: 8
                )

            Image(systemName: appModel.speech.isRecording ? "waveform" : "mic")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.white)
        }
        .scaleEffect(appModel.speech.isRecording || isPressingMicrophone ? 0.97 : 1)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    beginPressToTalkIfNeeded()
                }
                .onEnded { _ in
                    endPressToTalk()
                }
        )
    }

    private var voiceFeedbackPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: appModel.speech.isRecording ? "waveform" : "text.bubble")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appModel.speech.isRecording ? .red : AppTheme.accent)

                Text(appModel.speech.isRecording ? "录音中" : "文字")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            if let visibleVoiceText {
                editableVoiceDraft(text: visibleVoiceText)
            } else if appModel.speech.isRecording {
                Text("正在录音")
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

            if canSubmitVoiceDraft {
                Divider()

                HStack(spacing: 10) {
                    Button("清空") {
                        clearVoiceDraft()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    Button(searchIntentButtonTitle) {
                        Task {
                            await appModel.submitCaptureDraft()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(searchIntentButtonColor.opacity(0.14))
                    )
                    .foregroundStyle(searchIntentButtonColor)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private var shouldShowVoiceFeedback: Bool {
        appModel.speech.isRecording
            || visibleVoiceText != nil
            || feedbackStatusMessage != nil
    }

    @ViewBuilder
    private func editableVoiceDraft(text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("文字")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("输入内容", text: Binding(
                get: { appModel.captureText },
                set: { newValue in
                    appModel.updateCaptureDraftText(newValue)
                }
            ), axis: .vertical)
            .textFieldStyle(.plain)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(3...8)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.surfaceMuted)
            )

        }
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
                ("类型", "搜索")
            ]
        }

        guard let parsed = appModel.preview(for: visibleVoiceText) else {
            return []
        }

        var rows: [(label: String, value: String)] = [
            ("类型", parsed.record.displayCategoryName)
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

        if let storageContainer = parsed.record.resolvedStorageContainer {
            rows.append(("收纳", storageContainer.displayName))
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

    private var restingStatusMessage: String? {
        guard !appModel.speech.isRecording,
              visibleVoiceText == nil,
              appModel.speech.errorMessage == nil,
              let statusMessage = appModel.statusMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !statusMessage.isEmpty else {
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

    private var canSubmitVoiceDraft: Bool {
        !appModel.speech.isRecording && visibleVoiceText != nil
    }

    private var searchIntentButtonTitle: String {
        guard let visibleVoiceText else { return "保存" }
        return SearchIntentClassifier.isSearchQuery(visibleVoiceText) ? "去搜索" : "保存"
    }

    private var searchIntentButtonColor: Color {
        guard let visibleVoiceText else { return AppTheme.accent }
        return SearchIntentClassifier.isSearchQuery(visibleVoiceText) ? AppTheme.reminder : AppTheme.accent
    }

    private func syncPinnedVoiceText(from text: String) {
        pinnedVoiceText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginPressToTalkIfNeeded() {
        guard !isPressingMicrophone else { return }
        isPressingMicrophone = true
        appModel.startVoiceCapture()
    }

    private func endPressToTalk() {
        guard isPressingMicrophone || appModel.speech.isRecording else { return }
        isPressingMicrophone = false
        appModel.stopVoiceCapture()
    }

    private func clearVoiceDraft() {
        pinnedVoiceText = ""
        appModel.clearCaptureDraft()
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
