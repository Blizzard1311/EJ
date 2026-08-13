import SwiftUI
import YijiCore

struct RecordEditorView: View {
    private struct StorageSceneOption: Identifiable {
        let id: String
        let title: String
        let builtInContainer: StorageContainer?
    }

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Record
    @State private var selectedStorageSceneID: String
    @State private var tagsText: String
    @State private var contentText: String
    @State private var saveErrorMessage: String?
    @State private var isSaving = false
    @State private var hasEditedContent = false
    @State private var showingDeleteConfirmation = false

    private let initialStorageSceneID: String?
    let onSave: (Record) async -> Bool
    let onDelete: () async -> Void

    init(
        record: Record,
        initialStorageSceneID: String?,
        onSave: @escaping (Record) async -> Bool,
        onDelete: @escaping () async -> Void
    ) {
        _draft = State(initialValue: record)
        _selectedStorageSceneID = State(initialValue: initialStorageSceneID ?? "")
        _tagsText = State(initialValue: record.tags.joined(separator: "，"))
        _contentText = State(initialValue: record.content)
        self.initialStorageSceneID = initialStorageSceneID
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroCard

                    editorCard(title: "物品信息") {
                        VStack(spacing: 12) {
                            fieldGroup(title: "物品名称") {
                                TextField("输入物品名称", text: objectNameBinding)
                            }

                            fieldGroup(title: "当前位置") {
                                TextField("输入当前位置", text: locationBinding, axis: .vertical)
                                    .lineLimit(2...4)
                            }

                            pickerGroup(title: "收纳场景", selectionText: selectedStorageSceneTitle) {
                                ForEach(storageSceneOptions) { option in
                                    Button(option.title) {
                                        selectedStorageSceneID = option.id
                                    }
                                }

                                if !selectedStorageSceneID.isEmpty {
                                    Divider()
                                    Button("不指定") {
                                        selectedStorageSceneID = ""
                                    }
                                }
                            }
                        }
                    }

                    editorCard(title: "补充信息") {
                        VStack(spacing: 12) {
                            fieldGroup(title: "标签") {
                                TextField("多个标签用逗号分隔", text: $tagsText, axis: .vertical)
                                    .lineLimit(1...3)
                            }

                            fieldGroup(title: "原始描述") {
                                TextField(
                                    "输入原始描述",
                                    text: $contentText,
                                    axis: .vertical
                                )
                                .lineLimit(4...8)
                                .onChange(of: contentText) { _ in
                                    hasEditedContent = true
                                }
                            }
                        }
                    }

                    editorCard(title: "最近移动") {
                        HStack(spacing: 10) {
                            Image(systemName: "clock")
                                .foregroundStyle(Color(red: 0.36, green: 0.49, blue: 0.30))
                                .frame(width: 22)
                            Text("上次更新：\(YijiDateFormatter.dateTimeFormatter.string(from: draft.updatedAt))")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(red: 0.97, green: 0.98, blue: 0.96))
                        )
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("删除记录", systemImage: "trash")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.red.opacity(0.6), lineWidth: 1.2)
                    )
                }
                .padding(16)
            }
            .background(screenBackground)
            .navigationTitle("编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveBar
            }
            .confirmationDialog(
                "删除后，这条收纳记录将从列表中移除。",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("删除记录", role: .destructive) {
                    Task {
                        isSaving = true
                        await onDelete()
                        isSaving = false
                        dismiss()
                    }
                }
                Button("取消", role: .cancel) {}
            }
        }
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

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                statusBadge(title: "物品位置", color: .blue)
                if !selectedStorageSceneTitle.isEmpty {
                    statusBadge(title: selectedStorageSceneTitle, color: Color(red: 0.45, green: 0.58, blue: 0.41))
                }
            }

            Text(draft.location?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? draft.location! : "还没有填写当前位置")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.92))
        )
    }

    private var currentTitle: String {
        let trimmed = draft.objectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "编辑收纳记录" : trimmed
    }

    private var objectNameBinding: Binding<String> {
        Binding(
            get: { draft.objectName ?? "" },
            set: { draft.objectName = $0 }
        )
    }

    private var locationBinding: Binding<String> {
        Binding(
            get: { draft.location ?? "" },
            set: { draft.location = $0 }
        )
    }

    private var selectedStorageSceneTitle: String {
        storageSceneOptions.first(where: { $0.id == selectedStorageSceneID })?.title ?? ""
    }

    private var storageSceneOptions: [StorageSceneOption] {
        var options: [StorageSceneOption] = []
        var seenIDs: Set<String> = []

        for definition in appModel.storageContainerDefinitions {
            let option = StorageSceneOption(
                id: definition.id,
                title: definition.displayName,
                builtInContainer: definition.builtInContainer
            )
            if seenIDs.insert(option.id).inserted {
                options.append(option)
            }
        }

        for container in StorageContainer.allCases where !seenIDs.contains(container.rawValue) {
            options.append(
                StorageSceneOption(
                    id: container.rawValue,
                    title: container.displayName,
                    builtInContainer: container
                )
            )
        }

        if !selectedStorageSceneID.isEmpty,
           !options.contains(where: { $0.id == selectedStorageSceneID }),
           let customName = draft.customStorageContainerName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !customName.isEmpty {
            options.insert(
                StorageSceneOption(
                    id: selectedStorageSceneID,
                    title: customName,
                    builtInContainer: nil
                ),
                at: 0
            )
        }

        return options
    }

    private func editorCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppLocalization.text(title))
                .font(.headline.weight(.semibold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.92))
        )
    }

    private func fieldGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.text(title))
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
                )
        }
    }

    private func pickerGroup<Content: View>(
        title: String,
        selectionText: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.text(title))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selectionText.isEmpty ? "未指定" : selectionText)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
            )
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
            )
            .foregroundStyle(color)
    }

    private var saveBar: some View {
        VStack(spacing: 8) {
            if let saveErrorMessage {
                Text(saveErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await save() }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSaving ? "保存中..." : "完成")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.48, green: 0.58, blue: 0.41))
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private func save() async {
        guard !isSaving else { return }

        let objectName = draft.objectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let location = draft.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !objectName.isEmpty else {
            saveErrorMessage = "请填写物品名称。"
            return
        }

        guard !location.isEmpty else {
            saveErrorMessage = "请填写当前位置。"
            return
        }

        isSaving = true
        saveErrorMessage = nil

        var updated = draft
        let originalLocation = draft.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updated.objectName = objectName
        let normalizedInitialSceneID = initialStorageSceneID ?? ""
        let didChangeStorageScene = selectedStorageSceneID != normalizedInitialSceneID

        let trimmedContent = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.tags = normalizedTags(from: tagsText)
        updated.updatedAt = Date()

        var resolvedLocation = location
        if let selectedScene = storageSceneOptions.first(where: { $0.id == selectedStorageSceneID }) {
            updated.storageContainer = selectedScene.builtInContainer
            updated.customStorageContainerName = selectedScene.builtInContainer == nil ? selectedScene.title : nil

            if didChangeStorageScene, location == originalLocation {
                resolvedLocation = selectedScene.title
            }
        } else {
            updated.storageContainer = nil
            updated.customStorageContainerName = nil
        }

        updated.location = resolvedLocation

        if hasEditedContent {
            updated.content = trimmedContent.isEmpty
                ? generatedContent(objectName: objectName, location: resolvedLocation)
                : trimmedContent
        } else {
            updated.content = generatedContent(objectName: objectName, location: resolvedLocation)
        }

        let saved = await onSave(updated)
        isSaving = false

        if saved {
            dismiss()
        } else {
            saveErrorMessage = "保存失败，请重试。"
        }
    }

    private func normalizedTags(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "，", with: ",")
            .components(separatedBy: ",")
            .flatMap { $0.components(separatedBy: .newlines) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, tag in
                if !result.contains(tag) {
                    result.append(tag)
                }
            }
    }

    private func generatedContent(objectName: String, location: String) -> String {
        "\(objectName)放在\(location)"
    }
}
