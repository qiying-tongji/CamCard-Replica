import Contacts
import ContactsUI
import PhotosUI
import SwiftData
import SwiftUI

/// 添加名片的入口。只提供相册、通讯录和手动输入。
struct AddCardMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showManual = false
    @State private var showContacts = false
    @State private var closeAfterImport = false
    @State private var showEmptyContact = false
    @State private var showLibrary = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var importPhoto: ImportedPhoto?

    var body: some View {
        VStack(spacing: 0) {
            optionRow("从相册导入", systemImage: "photo") {
                showLibrary = true
            }
            optionRow("导入通讯录联系人", systemImage: "person.crop.rectangle") {
                showContacts = true
            }
            optionRow("手动输入名片", systemImage: "square.and.pencil") {
                showManual = true
            }
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("添加名片")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let image = await PickedPhoto.load(newItem) {
                    importPhoto = ImportedPhoto(image: image)
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(item: $importPhoto) { photo in
            CardImportFlow(image: photo.image, onCancel: {
                importPhoto = nil
            }, onSaved: {
                importPhoto = nil
                dismiss()
            })
        }
        .navigationDestination(isPresented: $showManual) {
            ManualCardAddView()
        }
        .sheet(isPresented: $showContacts) {
            ContactPicker { contact in
                if importContact(contact) {
                    closeAfterImport = true
                } else {
                    showEmptyContact = true
                }
            }
        }
        .onChange(of: showContacts) { _, isOpen in
            if !isOpen, closeAfterImport {
                closeAfterImport = false
                dismiss()
            }
        }
        .alert("没有可导入的内容", isPresented: $showEmptyContact) {
            Button("好", role: .cancel) {}
        } message: {
            Text("这个联系人没有姓名、公司、电话或邮箱。")
        }
    }

    private func optionRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 56)
        }
    }

    private func importContact(_ contact: CNContact) -> Bool {
        guard let card = ContactCardImporter.card(from: contact) else { return false }
        modelContext.insert(card)
        try? modelContext.save()
        return true
    }
}

/// 系统联系人选择器。只返回用户点中的那一位，不读取整本通讯录。
private struct ImportedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ContactPicker: UIViewControllerRepresentable {
    let onSelect: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactOrganizationNameKey,
            CNContactJobTitleKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey,
            CNContactUrlAddressesKey,
            CNContactPostalAddressesKey,
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (CNContact) -> Void

        init(onSelect: @escaping (CNContact) -> Void) {
            self.onSelect = onSelect
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact)
        }
    }
}

private enum ContactCardImporter {
    static func card(from contact: CNContact) -> BusinessCard? {
        let numbers = phoneNumbers(in: contact)
        let card = BusinessCard(
            name: personName(contact),
            company: text(contact.organizationName),
            jobTitle: text(contact.jobTitle),
            mobile: numbers.mobile,
            phone: numbers.phone,
            email: text(contact.emailAddresses.first?.value as String?),
            website: text(contact.urlAddresses.first?.value as String?),
            address: postalAddress(contact.postalAddresses.first?.value)
        )
        let fields = [card.name, card.company, card.jobTitle, card.mobile, card.phone, card.email, card.website, card.address]
        return fields.contains(where: { $0 != nil }) ? card : nil
    }

    private static func personName(_ contact: CNContact) -> String? {
        let family = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let given = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        if family.isEmpty, given.isEmpty { return nil }
        if containsCJK(family) || containsCJK(given) {
            return text(family + given)
        }
        return text([given, family].filter { !$0.isEmpty }.joined(separator: " "))
    }

    private static func phoneNumbers(in contact: CNContact) -> (mobile: String?, phone: String?) {
        var mobile: String?
        var phone: String?
        for item in contact.phoneNumbers {
            let label = item.label ?? ""
            if label == CNLabelPhoneNumberHomeFax || label == CNLabelPhoneNumberWorkFax { continue }
            guard let number = text(item.value.stringValue) else { continue }
            let isMobile = label == CNLabelPhoneNumberMobile || label == CNLabelPhoneNumberiPhone
            if isMobile, mobile == nil {
                mobile = number
            } else if phone == nil, number != mobile {
                phone = number
            }
        }
        return (mobile, phone)
    }

    private static func postalAddress(_ address: CNPostalAddress?) -> String? {
        guard let address else { return nil }
        return text(CNPostalAddressFormatter().string(from: address))
    }

    private static func text(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }
}
