import Foundation

/// 把一张名片写成 vCard 3.0 文本。空字段不输出。不访问系统通讯录。
enum VCFExporter {
    static func vCardString(from card: BusinessCard) -> String {
        var lines = ["BEGIN:VCARD", "VERSION:3.0"]
        if let name = text(card.name) {
            lines.append("FN:\(escape(name))")
            lines.append("N:\(nameComponents(name))")
        }
        if let company = text(card.company) {
            lines.append("ORG:\(escape(company))")
        }
        if let jobTitle = text(card.jobTitle) {
            lines.append("TITLE:\(escape(jobTitle))")
        }
        if let mobile = text(card.mobile) {
            lines.append("TEL;TYPE=CELL:\(escape(mobile))")
        }
        if let phone = text(card.phone) {
            lines.append("TEL;TYPE=WORK:\(escape(phone))")
        }
        if let email = text(card.email) {
            lines.append("EMAIL:\(escape(email))")
        }
        if let website = text(card.website) {
            lines.append("URL:\(escape(website))")
        }
        if let address = text(card.address) {
            lines.append("ADR:;;\(escape(address));;;;")
        }
        lines.append("END:VCARD")
        return lines.map(fold).joined()
    }

    static func writeTemporaryFile(for card: BusinessCard) throws -> URL {
        try writeTemporaryFile(for: [card], filename: filename(for: card))
    }

    static func writeTemporaryFile(for cards: [BusinessCard], filename: String) throws -> URL {
        let vcard = cards.map { vCardString(from: $0) }.joined()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(sanitizedFilename(filename))
            .appendingPathExtension("vcf")
        try Data(vcard.utf8).write(to: url, options: .atomic)
        return url
    }

    private static func text(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 有空格时，最后一个词作姓，其余作名。没有空格时整段放在姓的位置，避免拆开复姓。
    private static func nameComponents(_ name: String) -> String {
        let parts = name.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 2, let family = parts.last else {
            return "\(escape(name));;;;"
        }
        let given = parts.dropLast().joined(separator: " ")
        return "\(escape(family));\(escape(given));;;"
    }

    /// vCard 文本里的反斜杠、分号、逗号和换行必须转义。
    private static func escape(_ value: String) -> String {
        var text = value.replacingOccurrences(of: "\\", with: "\\\\")
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")
        text = text.replacingOccurrences(of: "\n", with: "\\n")
        text = text.replacingOccurrences(of: ";", with: "\\;")
        text = text.replacingOccurrences(of: ",", with: "\\,")
        return text
    }

    /// 物理行按 UTF-8 字节折到 75 以内，续行以 CRLF 加一个空格开始。
    private static func fold(_ line: String) -> String {
        var output = ""
        var current = ""
        var octets = 0
        var limit = 75
        for character in line {
            let size = Data(String(character).utf8).count
            if octets > 0, octets + size > limit {
                output += current + "\r\n "
                current = String(character)
                octets = 1 + size
                limit = 75
            } else {
                current.append(character)
                octets += size
            }
        }
        output += current + "\r\n"
        return output
    }

    private static func filename(for card: BusinessCard) -> String {
        sanitizedFilename(text(card.name) ?? "名片")
    }

    private static func sanitizedFilename(_ raw: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = raw.components(separatedBy: forbidden).joined()
        return cleaned.isEmpty ? "名片" : cleaned
    }
}
