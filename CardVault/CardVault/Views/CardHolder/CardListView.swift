import Contacts
import SwiftData
import SwiftUI
import UIKit

/// 名片夹首页。搜索、标签、排序和批量操作都在本地列表上完成。
struct CardListView: View {
    @Binding var selectedTab: AppTab
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessCard.createdAt, order: .reverse) private var cards: [BusinessCard]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var searchText = ""
    @State private var selectedTagID: UUID?
    @State private var sort: CardSort = .date
    @State private var showManage = false
    @State private var allExportURL: URL?
    @State private var pendingAction: CardManageAction?
    @State private var showAdd = false
    @State private var showDedup = false
    @State private var isSelecting = false
    @State private var selection: Set<UUID> = []
    @State private var batchExportURL: URL?
    @State private var showBatchDelete = false
    @State private var showBatchMore = false
    @State private var contactsAlert: ContactsAlert?

    init(selectedTab: Binding<AppTab>) {
        _selectedTab = selectedTab
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    VStack(spacing: 0) {
                        holderBar
                        emptyState
                    }
                } else {
                    filteredContent
                }
            }
            .navigationTitle(isSelecting ? "" : "名片夹")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(CardListSearchBar(isSelecting: isSelecting, text: $searchText))
            .toolbar {
                if isSelecting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            finishSelecting()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .accessibilityLabel("完成")
                    }
                    ToolbarItem(placement: .principal) {
                        Text("已选择\(selection.count)项")
                            .font(.headline)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(allVisibleSelected ? "取消全选" : "全选") {
                            toggleSelectAll()
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("扫描") {
                            selectedTab = .scan
                        }
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let card = cards.first(where: { $0.id == id }) {
                    CardDetailView(card: card)
                }
            }
            .navigationDestination(isPresented: $showAdd) {
                AddCardMenuView()
            }
            .navigationDestination(isPresented: $showDedup) {
                CardDedupView()
            }
            .sheet(isPresented: $showManage, onDismiss: performPendingAction) {
                CardManageSheet(sort: $sort, exportURL: allExportURL, hasCards: !cards.isEmpty) { action in
                    pendingAction = action
                }
            }
            .onChange(of: showManage) { _, isOpen in
                if isOpen {
                    allExportURL = cards.isEmpty
                        ? nil
                        : try? VCFExporter.writeTemporaryFile(for: cards, filename: "全部名片")
                }
            }
            .onChange(of: selection) { _, _ in
                refreshBatchExport()
            }
            .confirmationDialog(
                "删除所选的 \(selection.count) 张名片？",
                isPresented: $showBatchDelete,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) { deleteSelected() }
                Button("取消", role: .cancel) {}
            }
            .alert(item: $contactsAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("好"))
                )
            }
            .overlay {
                if showBatchMore {
                    batchMoreMenu
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    batchBar
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("还没有名片")
                .font(.title2)
            Button("扫描第一张名片") {
                selectedTab = .scan
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredContent: some View {
        VStack(spacing: 0) {
            if !isSelecting {
                holderBar
                if !tags.isEmpty {
                    tagFilterBar
                }
            }
            if filteredCards.isEmpty {
                Text("没有匹配的名片")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                cardList
            }
        }
    }

    private var holderBar: some View {
        HStack {
            Button {
                selectedTagID = nil
            } label: {
                Text("全部 \(cards.count)")
                    .font(.body.weight(selectedTagID == nil ? .semibold : .regular))
                    .foregroundStyle(selectedTagID == nil ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Button("管理") {
                showManage = true
            }
            .foregroundStyle(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var cardList: some View {
        List {
            if sort == .date {
                ForEach(dateSections) { section in
                    Section {
                        ForEach(section.cards) { card in
                            cardLink(card)
                        }
                    } header: {
                        Text(section.id)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            } else {
                ForEach(sortedCards) { card in
                    cardLink(card, showsDate: true)
                }
            }
        }
        .listStyle(.plain)
    }

    private func cardLink(_ card: BusinessCard, showsDate: Bool = false) -> some View {
        Group {
            if isSelecting {
                let selected = selection.contains(card.id)
                Button {
                    if selected {
                        selection.remove(card.id)
                    } else {
                        selection.insert(card.id)
                    }
                } label: {
                    CardRow(card: card, showsDate: showsDate, marked: selected)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .listRowBackground(selected ? Color.accentColor.opacity(0.18) : Color.clear)
            } else {
                NavigationLink(value: card.id) {
                    CardRow(card: card, showsDate: showsDate)
                }
            }
        }
    }

    private var batchBar: some View {
        HStack(spacing: 0) {
            batchAction("存入通讯录", systemImage: "person.crop.rectangle") {
                Task { await saveSelectedToContacts() }
            }
            batchAction("更多", systemImage: "ellipsis") {
                showBatchMore = true
            }
        }
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func batchAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selection.isEmpty ? Color.secondary : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(selection.isEmpty)
    }

    private var batchMoreMenu: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { showBatchMore = false }
            VStack(alignment: .leading, spacing: 0) {
                Text("更多")
                    .font(.headline)
                    .padding()
                if let batchExportURL {
                    ShareLink(
                        item: VCFDocument(url: batchExportURL),
                        preview: SharePreview(batchExportURL.lastPathComponent)
                    ) {
                        Text("分享")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("分享")
                        .foregroundStyle(.tertiary)
                        .padding()
                }
                Divider()
                Button(role: .destructive) {
                    showBatchMore = false
                    showBatchDelete = true
                } label: {
                    Text("删除选中名片")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .buttonStyle(.plain)
            }
            .frame(width: 260)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var allVisibleSelected: Bool {
        let visible = Set(sortedCards.map(\.id))
        return !visible.isEmpty && visible.isSubset(of: selection)
    }

    private func toggleSelectAll() {
        let visible = Set(sortedCards.map(\.id))
        if allVisibleSelected {
            selection.subtract(visible)
        } else {
            selection.formUnion(visible)
        }
    }

    private func finishSelecting() {
        isSelecting = false
        selection.removeAll()
        batchExportURL = nil
        showBatchMore = false
    }

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags) { tag in
                    let selected = selectedTagID == tag.id
                    Button(tag.name) {
                        selectedTagID = selected ? nil : tag.id
                    }
                    .buttonStyle(.bordered)
                    .tint(selected ? Color.accentColor : Color.secondary)
                    .contextMenu {
                        Button("删除标签", role: .destructive) {
                            deleteTag(tag)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var filteredCards: [BusinessCard] {
        cards.filter { card in
            matchesSearch(card) && matchesSelectedTag(card)
        }
    }

    private var sortedCards: [BusinessCard] {
        switch sort {
        case .date:
            return filteredCards.sorted { $0.createdAt > $1.createdAt }
        case .name:
            return filteredCards.sorted { comesBefore(sortText($0.name), sortText($1.name)) }
        case .company:
            return filteredCards.sorted { comesBefore(sortText($0.company), sortText($1.company)) }
        }
    }

    private var dateSections: [CardDaySection] {
        var titles: [String] = []
        var buckets: [String: [BusinessCard]] = [:]
        for card in sortedCards {
            let title = CardDateFormat.day.string(from: card.createdAt)
            if buckets[title] == nil {
                titles.append(title)
            }
            buckets[title, default: []].append(card)
        }
        return titles.map { CardDaySection(id: $0, cards: buckets[$0] ?? []) }
    }

    private func matchesSearch(_ card: BusinessCard) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let fields = [card.name, card.company, card.jobTitle, card.mobile, card.phone, card.email]
        return fields.contains { value in
            value?.localizedCaseInsensitiveContains(query) == true
        }
    }

    private func matchesSelectedTag(_ card: BusinessCard) -> Bool {
        guard let selectedTagID else { return true }
        return card.tags.contains { $0.id == selectedTagID }
    }

    private func sortText(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "\u{10FFFF}" : trimmed
    }

    private func comesBefore(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    private func performPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            switch action {
            case .batch:
                isSelecting = true
                selection.removeAll()
                batchExportURL = nil
            case .add:
                showAdd = true
            case .scan:
                selectedTab = .scan
            case .deduplicate:
                showDedup = true
            }
        }
    }

    private func refreshBatchExport() {
        let chosen = cards.filter { selection.contains($0.id) }
        batchExportURL = chosen.isEmpty ? nil : try? VCFExporter.writeTemporaryFile(for: chosen, filename: "已选名片")
    }

    private func saveSelectedToContacts() async {
        let chosen = cards.filter { selection.contains($0.id) }
        guard !chosen.isEmpty else { return }
        let granted = await requestContactsAccess()
        guard granted else {
            contactsAlert = ContactsAlert(
                title: "无法存入通讯录",
                message: "需要通讯录权限才能保存名片。可以在系统设置里为 CardVault 打开通讯录。"
            )
            return
        }
        let store = CNContactStore()
        let request = CNSaveRequest()
        for card in chosen {
            request.add(ContactCardWriter.contact(from: card), toContainerWithIdentifier: nil)
        }
        do {
            try store.execute(request)
            contactsAlert = ContactsAlert(title: "已存入通讯录", message: "已保存 \(chosen.count) 位联系人。")
        } catch {
            contactsAlert = ContactsAlert(title: "存入失败", message: "这张名片没有写入通讯录。")
        }
    }

    private func requestContactsAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                CNContactStore().requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    private func deleteSelected() {
        for card in cards where selection.contains(card.id) {
            modelContext.delete(card)
        }
        try? modelContext.save()
        selection.removeAll()
        batchExportURL = nil
        isSelecting = false
    }

    private func deleteTag(_ tag: Tag) {
        if selectedTagID == tag.id {
            selectedTagID = nil
        }
        for card in tag.cards {
            card.tags.removeAll { $0.id == tag.id }
        }
        modelContext.delete(tag)
        try? modelContext.save()
    }
}

private struct CardDaySection: Identifiable {
    let id: String
    let cards: [BusinessCard]
}

private enum CardDateFormat {
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct ContactsAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct CardListSearchBar: ViewModifier {
    let isSelecting: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isSelecting {
            content
        } else {
            content.searchable(text: $text, prompt: "输入姓名/职位/公司/电话/邮箱")
        }
    }
}

private enum ContactCardWriter {
    static func contact(from card: BusinessCard) -> CNMutableContact {
        let contact = CNMutableContact()
        let name = trimmed(card.name)
        if let name {
            if name.contains(where: \.isWhitespace) {
                let parts = name.split(whereSeparator: \.isWhitespace).map(String.init)
                contact.familyName = parts.last ?? name
                contact.givenName = parts.dropLast().joined(separator: " ")
            } else {
                contact.familyName = name
            }
        }
        if let company = trimmed(card.company) { contact.organizationName = company }
        if let jobTitle = trimmed(card.jobTitle) { contact.jobTitle = jobTitle }
        if let mobile = trimmed(card.mobile) {
            contact.phoneNumbers.append(CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: mobile)))
        }
        if let phone = trimmed(card.phone) {
            contact.phoneNumbers.append(CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone)))
        }
        if let email = trimmed(card.email) {
            contact.emailAddresses.append(CNLabeledValue(label: CNLabelWork, value: email as NSString))
        }
        if let website = trimmed(card.website) {
            contact.urlAddresses.append(CNLabeledValue(label: CNLabelWork, value: website as NSString))
        }
        if let address = trimmed(card.address) {
            let postal = CNMutablePostalAddress()
            postal.street = address
            contact.postalAddresses.append(CNLabeledValue(label: CNLabelWork, value: postal))
        }
        return contact
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

private struct CardRow: View {
    let card: BusinessCard
    var showsDate = false
    var marked = false

    var body: some View {
        HStack(spacing: 12) {
            CardThumbnail(data: card.processedImageData ?? card.originalImageData)
                .overlay {
                    if marked {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 2)
                    }
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name ?? "未命名")
                    .font(.headline)
                if let jobTitle = card.jobTitle, !jobTitle.isEmpty {
                    Text(jobTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
            if showsDate {
                Spacer(minLength: 8)
                Text(CardDateFormat.day.string(from: card.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CardThumbnail: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.rectangle")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 40)
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview("空状态") {
    CardListView(selectedTab: .constant(.cardHolder))
        .modelContainer(CardListPreview.container(includingSamples: false))
}

#Preview("有名片") {
    CardListView(selectedTab: .constant(.cardHolder))
        .modelContainer(CardListPreview.container(includingSamples: true))
}

@MainActor
private enum CardListPreview {
    static func container(includingSamples: Bool) -> ModelContainer {
        let schema = Schema([BusinessCard.self, Tag.self, OCRResult.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            if includingSamples {
                var samples = sampleCards()
                let tag = Tag(name: "客户")
                container.mainContext.insert(tag)
                samples[0].tags = [tag]
                samples.forEach { container.mainContext.insert($0) }
            }
            return container
        } catch {
            fatalError("预览数据库创建失败: \(error)")
        }
    }

    static func sampleCards() -> [BusinessCard] {
        [
            BusinessCard(
                originalImageData: sampleImageData(),
                name: "何予安",
                company: "津渡咨询",
                mobile: "13800001013",
                createdAt: .now
            ),
            BusinessCard(
                name: "马听澜",
                company: "石桥制造",
                mobile: "13900001014",
                createdAt: Date(timeIntervalSinceNow: -86_400)
            ),
            BusinessCard(
                createdAt: Date(timeIntervalSinceNow: -172_800)
            ),
        ]
    }

    static func sampleImageData() -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 96))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 96))
        }
        return image.pngData()
    }
}
