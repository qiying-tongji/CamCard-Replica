import CoreTransferable
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum CardSort: String, CaseIterable, Identifiable {
    case date
    case name
    case company

    var id: Self { self }

    var title: String {
        switch self {
        case .date: "按日期"
        case .name: "按姓名"
        case .company: "按公司"
        }
    }

    var systemImage: String {
        switch self {
        case .date: "clock"
        case .name: "person"
        case .company: "building.2"
        }
    }
}

enum CardManageAction {
    case batch
    case add
    case scan
    case deduplicate
}

struct VCFDocument: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .vCard) { file in
            SentTransferredFile(file.url)
        } importing: { _ in
            throw CocoaError(.fileReadUnsupportedScheme)
        }
    }
}

/// 管理面板。排序立刻作用在列表上，其余操作等面板关闭后再执行。
struct CardManageSheet: View {
    @Binding var sort: CardSort
    let exportURL: URL?
    let hasCards: Bool
    let onChoose: (CardManageAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("关闭")
            }

            sectionTitle("排序方式")
            HStack(spacing: 10) {
                ForEach(CardSort.allCases) { item in
                    sortButton(item)
                }
            }

            sectionTitle("批量操作")
            HStack(spacing: 8) {
                actionButton("批量操作", systemImage: "checkmark.square", enabled: hasCards) {
                    choose(.batch)
                }
                if let exportURL {
                    ShareLink(
                        item: VCFDocument(url: exportURL),
                        preview: SharePreview(exportURL.lastPathComponent)
                    ) {
                        actionLabel("导出", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                } else {
                    actionButton("导出", systemImage: "square.and.arrow.up", enabled: false) {}
                }
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }

            sectionTitle("名片管理")
            HStack(spacing: 8) {
                actionButton("添加名片", systemImage: "plus.circle") {
                    choose(.add)
                }
                actionButton("扫一扫", systemImage: "viewfinder") {
                    choose(.scan)
                }
                actionButton("名片去重", systemImage: "rectangle.on.rectangle.dashed", enabled: hasCards) {
                    choose(.deduplicate)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private func choose(_ action: CardManageAction) {
        onChoose(action)
        dismiss()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func sortButton(_ item: CardSort) -> some View {
        let selected = sort == item
        return Button {
            sort = item
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.systemImage)
                Text(item.title)
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? Color.accentColor : Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func actionButton(
        _ title: String,
        systemImage: String,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionLabel(title, systemImage: systemImage)
                .foregroundStyle(enabled ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(height: 28)
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ManualCardAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var draft = CardFieldDraft()

    var body: some View {
        CardFieldForm(draft: $draft)
            .navigationTitle("手动输入名片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
    }

    private var canSave: Bool {
        [draft.name, draft.company, draft.jobTitle, draft.mobile, draft.phone, draft.email, draft.website, draft.address]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func save() {
        let card = BusinessCard()
        draft.apply(to: card)
        modelContext.insert(card)
        try? modelContext.save()
        dismiss()
    }
}

struct CardDedupView: View {
    @Query(sort: \BusinessCard.createdAt, order: .reverse) private var cards: [BusinessCard]
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDelete: BusinessCard?

    var body: some View {
        Group {
            let groups = CardDuplicateFinder.groups(in: cards)
            if groups.isEmpty {
                ContentUnavailableView(
                    "没有重复的名片",
                    systemImage: "checkmark.circle",
                    description: Text("手机号或电话相同，以及姓名和公司都相同的名片会列在这里。")
                )
            } else {
                List {
                    ForEach(groups) { group in
                        Section("重复 \(group.cards.count) 张") {
                            ForEach(group.cards) { card in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(card.name ?? "未命名")
                                            .font(.headline)
                                        if let company = card.company, !company.isEmpty {
                                            Text(company)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let mobile = card.mobile, !mobile.isEmpty {
                                            Text(mobile)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button("删除", role: .destructive) {
                                        pendingDelete = card
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("名片去重")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "删除这张重复名片？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let card = pendingDelete {
                    modelContext.delete(card)
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        }
    }
}

enum CardDuplicateFinder {
    struct Group: Identifiable {
        let id: String
        let cards: [BusinessCard]
    }

    static func groups(in cards: [BusinessCard]) -> [Group] {
        var parent = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0.id) })

        func find(_ id: UUID) -> UUID {
            var current = id
            var seen: [UUID] = []
            while let next = parent[current], next != current {
                seen.append(current)
                current = next
            }
            for node in seen {
                parent[node] = current
            }
            return current
        }

        func unite(_ lhs: UUID, _ rhs: UUID) {
            let left = find(lhs)
            let right = find(rhs)
            if left != right {
                parent[left] = right
            }
        }

        var seen: [String: UUID] = [:]
        for card in cards {
            for key in keys(of: card) {
                if let other = seen[key] {
                    unite(card.id, other)
                } else {
                    seen[key] = card.id
                }
            }
        }

        var buckets: [UUID: [BusinessCard]] = [:]
        for card in cards {
            buckets[find(card.id), default: []].append(card)
        }
        return buckets.values
            .filter { $0.count > 1 }
            .map { group in
                let ordered = group.sorted { $0.createdAt > $1.createdAt }
                let id = ordered.map(\.id.uuidString).sorted().joined(separator: "-")
                return Group(id: id, cards: ordered)
            }
            .sorted { ($0.cards.first?.createdAt ?? .distantPast) > ($1.cards.first?.createdAt ?? .distantPast) }
    }

    private static func keys(of card: BusinessCard) -> [String] {
        var result: [String] = []
        for number in [card.mobile, card.phone] {
            let digits = number?.filter(\.isNumber) ?? ""
            if digits.count >= 6 {
                result.append("tel:\(digits)")
            }
        }
        if let name = normalized(card.name), let company = normalized(card.company) {
            result.append("nc:\(name)|\(company)")
        }
        return result
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return text.isEmpty ? nil : text
    }
}
