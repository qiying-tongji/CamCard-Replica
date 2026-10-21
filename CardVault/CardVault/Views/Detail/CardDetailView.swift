import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 名片详情。编辑复用核对表单，删除后回到列表。
struct CardDetailView: View {
    @Bindable var card: BusinessCard
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var showFullscreen = false
    @State private var showNewTag = false
    @State private var newTagName = ""
    @State private var notesDraft = ""
    @State private var didLoadNotes = false
    @State private var vcfURL: URL?

    init(card: BusinessCard) {
        self.card = card
    }

    var body: some View {
        List {
            Section {
                originalImage
            }
            Section {
                fieldRow("姓名 / Name", value: card.name)
                fieldRow("公司 / Company", value: card.company)
                fieldRow("职位 / Job Title", value: card.jobTitle)
                linkedRow("手机 / Mobile", value: card.mobile, url: CardLinks.telephone)
                linkedRow("电话 / Phone", value: card.phone, url: CardLinks.telephone)
                linkedRow("邮箱 / Email", value: card.email, url: CardLinks.mail)
                linkedRow("网址 / Website", value: card.website, url: CardLinks.website)
                fieldRow("地址 / Address", value: card.address)
            }
            tagSection
            notesSection
        }
        .onAppear {
            if !didLoadNotes {
                notesDraft = card.notes ?? ""
                didLoadNotes = true
            }
            refreshExportFile()
        }
        .onChange(of: exportSignature) { _, _ in
            refreshExportFile()
        }
        .onDisappear {
            saveNotes()
        }
        .alert("新建标签", isPresented: $showNewTag) {
            TextField("标签名称", text: $newTagName)
            Button("添加") {
                addTag(named: newTagName)
                newTagName = ""
            }
            Button("取消", role: .cancel) {
                newTagName = ""
            }
        } message: {
            Text("与已有标签同名时，会直接加到这张名片上。")
        }
        .navigationTitle("名片详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let vcfURL {
                    ShareLink(
                        item: VCFFile(url: vcfURL),
                        preview: SharePreview(vcfURL.lastPathComponent)
                    ) {
                        Text("导出")
                    }
                }
                Button("编辑") {
                    showEditor = true
                }
                Button("删除", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationDestination(isPresented: $showEditor) {
            EditView(card: card)
        }
        .confirmationDialog(
            "名片删除之后30天内可以到官网回收站进行恢复，请确认是否要删除所选名片？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                deleteCard()
            }
            Button("取消", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            if let image = originalUIImage {
                FullscreenCardImage(image: image)
            }
        }
    }

    @ViewBuilder
    private var originalImage: some View {
        if let image = originalUIImage {
            Button {
                showFullscreen = true
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("名片原图，轻点全屏查看")
        } else {
            Text("没有原图")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var originalUIImage: UIImage? {
        guard let data = card.processedImageData ?? card.originalImageData else { return nil }
        return UIImage(data: data)
    }

    private func fieldRow(_ title: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(displayText(value))
                .foregroundStyle(hasText(value) ? .primary : .tertiary)
        }
        .padding(.vertical, 2)
    }

    private func linkedRow(_ title: String, value: String?, url: (String) -> URL?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let value, hasText(value), let destination = url(value) {
                Button(value) {
                    openURL(destination)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            } else {
                Text("未填写")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func displayText(_ value: String?) -> String {
        hasText(value) ? value ?? "" : "未填写"
    }

    private func hasText(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tagSection: some View {
        Section("标签") {
            if card.tags.isEmpty {
                Text("还没有标签")
                    .foregroundStyle(.secondary)
            } else {
                tagScroller(card.tags.sorted { $0.name < $1.name }) { tag in
                    removableTag(tag)
                }
            }
            let available = allTags.filter { tag in
                !card.tags.contains { $0.id == tag.id }
            }
            if !available.isEmpty {
                Text("添加已有标签")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                tagScroller(available) { tag in
                    Button(tag.name) {
                        addExisting(tag)
                    }
                    .buttonStyle(.bordered)
                }
            }
            Button("新建标签") {
                newTagName = ""
                showNewTag = true
            }
        }
    }

    private var notesSection: some View {
        Section("备注") {
            TextField("添加备注", text: $notesDraft, axis: .vertical)
                .lineLimit(3...6)
                .onChange(of: notesDraft) { _, value in
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    card.notes = trimmed.isEmpty ? nil : value
                }
        }
    }

    private func tagScroller<Content: View>(_ tags: [Tag], @ViewBuilder chip: @escaping (Tag) -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags) { tag in
                    chip(tag)
                }
            }
        }
        .buttonStyle(.borderless)
    }

    private func removableTag(_ tag: Tag) -> some View {
        HStack(spacing: 6) {
            Text(tag.name)
            Button {
                removeTag(tag)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .accessibilityLabel("从名片移除\(tag.name)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.15), in: Capsule())
    }

    private func addExisting(_ tag: Tag) {
        guard !card.tags.contains(where: { $0.id == tag.id }) else { return }
        card.tags.append(tag)
        try? modelContext.save()
    }

    private func addTag(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if card.tags.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return
        }
        let tag: Tag
        if let existing = allTags.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            tag = existing
        } else {
            tag = Tag(name: name)
            modelContext.insert(tag)
        }
        card.tags.append(tag)
        try? modelContext.save()
    }

    private func removeTag(_ tag: Tag) {
        card.tags.removeAll { $0.id == tag.id }
        try? modelContext.save()
    }

    private var exportSignature: String {
        [card.name, card.company, card.jobTitle, card.mobile, card.phone, card.email, card.website, card.address]
            .map { $0 ?? "" }
            .joined(separator: "\u{1}")
    }

    private func refreshExportFile() {
        vcfURL = try? VCFExporter.writeTemporaryFile(for: card)
    }

    private func saveNotes() {
        let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        card.notes = trimmed.isEmpty ? nil : notesDraft
        try? modelContext.save()
    }

    private func deleteCard() {
        modelContext.delete(card)
        try? modelContext.save()
        dismiss()
    }
}

private struct FullscreenCardImage: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct VCFFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .vCard) { file in
            SentTransferredFile(file.url)
        } importing: { _ in
            throw CocoaError(.fileReadUnsupportedScheme)
        }
    }
}

private enum CardLinks {
    static func telephone(_ raw: String) -> URL? {
        let number = raw.filter { $0.isNumber || $0 == "+" }
        guard !number.isEmpty else { return nil }
        return URL(string: "tel:\(number)")
    }

    static func mail(_ raw: String) -> URL? {
        let address = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else { return nil }
        return URL(string: "mailto:\(address)")
    }

    static func website(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let prefixed = trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")
            ? trimmed
            : "https://\(trimmed)"
        return URL(string: prefixed)
    }
}
