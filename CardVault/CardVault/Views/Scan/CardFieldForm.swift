import SwiftData
import SwiftUI
import UIKit

/// 八个可编辑字段的草稿。空字符串在写入时变成 nil。
struct CardFieldDraft {
    var name = ""
    var company = ""
    var jobTitle = ""
    var mobile = ""
    var phone = ""
    var email = ""
    var website = ""
    var address = ""

    init() {}

    init(fields: ParsedFields) {
        name = fields.name ?? ""
        company = fields.company ?? ""
        jobTitle = fields.jobTitle ?? ""
        mobile = fields.mobile ?? ""
        phone = fields.phone ?? ""
        email = fields.email ?? ""
        website = fields.website ?? ""
        address = fields.address ?? ""
    }

    init(card: BusinessCard) {
        name = card.name ?? ""
        company = card.company ?? ""
        jobTitle = card.jobTitle ?? ""
        mobile = card.mobile ?? ""
        phone = card.phone ?? ""
        email = card.email ?? ""
        website = card.website ?? ""
        address = card.address ?? ""
    }

    func apply(to card: BusinessCard) {
        card.name = stored(name)
        card.company = stored(company)
        card.jobTitle = stored(jobTitle)
        card.mobile = stored(mobile)
        card.phone = stored(phone)
        card.email = stored(email)
        card.website = stored(website)
        card.address = stored(address)
    }

    private func stored(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// 核对页和编辑页共用的字段表单。
struct CardFieldForm: View {
    @Binding var draft: CardFieldDraft

    var body: some View {
        Form {
            textField("姓名 / Name", text: $draft.name)
            textField("公司 / Company", text: $draft.company)
            textField("职位 / Job Title", text: $draft.jobTitle)
            textField("手机 / Mobile", text: $draft.mobile, keyboard: .phonePad)
            textField("电话 / Phone", text: $draft.phone, keyboard: .phonePad)
            textField("邮箱 / Email", text: $draft.email, keyboard: .emailAddress)
            textField("网址 / Website", text: $draft.website, keyboard: .URL)
            textField("地址 / Address", text: $draft.address, axis: .vertical)
        }
    }

    private func textField(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: text, axis: axis)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .default ? .words : .never)
                .autocorrectionDisabled(keyboard != .default)
        }
        .padding(.vertical, 2)
    }
}
