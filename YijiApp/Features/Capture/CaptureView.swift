import SwiftUI
import UIKit
import YijiCore

struct CaptureView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    micHero
                    VStack(spacing: 6) {
                        Text("一句话记住位置、提醒和想法")
                            .font(.headline.weight(.semibold))
                        Text("点按开始听写，或直接套用下面的示例句。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.white.opacity(0.92))
                )
            }
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)

            Section {
                cardSection(title: "快速示例", subtitle: "先选一个句子，再按你的实际情况微调") {
                    exampleGrid
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)

            Section {
                cardSection(title: "输入内容", subtitle: "支持语音听写和手动编辑") {
                    Picker("来源", selection: Bindable(appModel).draftSource) {
                        Text("文字").tag(CaptureSource.text)
                        Text("语音").tag(CaptureSource.voice)
                    }
                    .pickerStyle(.segmented)

                    voiceCaptureControls

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: Bindable(appModel).captureText)
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
                            )

                        if appModel.captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("例如：我把户口本放在红抽屉最上面")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 14)
                                .padding(.leading, 14)
                                .allowsHitTesting(false)
                        }
                    }

                    HStack {
                        Button("清空内容") {
                            appModel.captureText = ""
                            if appModel.draftSource == .voice {
                                appModel.speech.resetTranscript()
                            }
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        if let latest = appModel.recentRecords.first {
                            Button("套用最近一条") {
                                appModel.draftSource = .text
                                appModel.captureText = latest.content
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .font(.footnote)

                    if let statusMessage = appModel.statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)

            Section {
                cardSection(title: "解析预览", subtitle: "保存之前，先确认系统理解得对不对") {
                    if let preview = appModel.preview(for: appModel.captureText) {
                        PreviewCard(parsed: preview)
                    } else {
                        Text("输入一句自然语言后，这里会展示解析结果。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)

            Section {
                Button(primaryButtonTitle) {
                    Task {
                        await appModel.saveCapture()
                    }
                }
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .foregroundStyle(.white)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 4, trailing: 16))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color(red: 0.2, green: 0.55, blue: 1.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .disabled(appModel.captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 6, trailing: 16))

            if !appModel.recentRecords.isEmpty {
                Section {
                    cardSection(title: "最近记录", subtitle: "可以复用最近的一条作为模板") {
                        ForEach(appModel.recentRecords) { record in
                            NavigationLink {
                                RecordDetailView(recordID: record.id)
                            } label: {
                                RecordRowView(record: record)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 18, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
        .navigationTitle("语音记录")
    }

    private var screenBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.96, blue: 0.99),
                Color(red: 0.98, green: 0.98, blue: 0.99)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var voiceCaptureControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button(appModel.speech.isRecording ? "停止听写" : "开始听写") {
                    Task {
                        if appModel.speech.isRecording {
                            appModel.stopVoiceCapture()
                        } else {
                            await appModel.startVoiceCapture()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                if appModel.speech.isRecording {
                    Label("识别中", systemImage: "waveform")
                        .foregroundStyle(.red)
                } else {
                    Text("权限：\(appModel.speech.authorizationStatus.displayName)")
                        .foregroundStyle(.secondary)
                }
            }

            if !appModel.speech.transcript.isEmpty {
                Text("实时转写：\(appModel.speech.transcript)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = appModel.speech.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if appModel.speech.authorizationStatus == .denied {
                Button("前往系统设置开启语音权限") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .font(.footnote.weight(.medium))
                .buttonStyle(.borderless)
            }
        }
    }

    private var micHero: some View {
        Button {
            Task {
                if appModel.speech.isRecording {
                    appModel.stopVoiceCapture()
                } else {
                    await appModel.startVoiceCapture()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(appModel.speech.isRecording ? Color.red.opacity(0.18) : Color.blue.opacity(0.14))
                    .frame(width: 164, height: 164)
                Circle()
                    .fill(appModel.speech.isRecording ? Color.red : Color.blue)
                    .frame(width: 112, height: 112)
                Image(systemName: appModel.speech.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func cardSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.92))
        )
    }

    private var exampleGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(examplePrompts, id: \.title) { prompt in
                    Button {
                        appModel.draftSource = .text
                        appModel.captureText = prompt.text
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(prompt.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(prompt.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var primaryButtonTitle: String {
        guard let preview = appModel.preview(for: appModel.captureText) else {
            return "保存记录"
        }

        if preview.reminder != nil {
            return "保存并创建提醒"
        }

        switch preview.record.category {
        case .storage:
            return "保存位置记录"
        case .note:
            return "保存笔记"
        case .reminder:
            return "保存提醒记录"
        case .other:
            return "保存记录"
        }
    }
}

private struct PreviewCard: View {
    let parsed: ParsedCapture

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("分类", value: parsed.record.category.displayName)
            if let objectName = parsed.record.objectName {
                LabeledContent("对象", value: objectName)
            }
            if let location = parsed.record.location {
                LabeledContent("位置", value: location)
            }
            if let reminder = parsed.reminder {
                LabeledContent("提醒时间", value: YijiDateFormatter.dateTimeFormatter.string(from: reminder.remindAt))
                LabeledContent("重复规则", value: reminder.repeatRule.displayName)
            }
            if !parsed.record.tags.isEmpty {
                LabeledContent("标签", value: parsed.record.tags.joined(separator: " / "))
            }
        }
        .font(.subheadline)
    }
}

private let examplePrompts: [(title: String, text: String)] = [
    ("物品定位", "我把户口本放在红抽屉最上面"),
    ("生活提醒", "明天下午三点提醒我交物业费"),
    ("周期提醒", "每月5号提醒我还信用卡"),
    ("想法笔记", "记一下：给孩子报名材料要放进蓝色文件夹")
]

#Preview("语音记录 - iPhone 16 Pro") {
    PreviewSupport.canvas {
        NavigationStack {
            CaptureView()
        }
    }
}

#Preview("语音记录 - Dark") {
    PreviewSupport.canvas(colorScheme: .dark) {
        NavigationStack {
            CaptureView()
        }
    }
}

#Preview("语音记录 - 权限未开启") {
    PreviewSupport.canvas(model: PreviewSupport.voiceDeniedAppModel(), device: "iPhone SE (3rd generation)") {
        NavigationStack {
            CaptureView()
        }
    }
}
