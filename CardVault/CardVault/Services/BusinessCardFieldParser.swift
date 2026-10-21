import Foundation

protocol BusinessCardFieldParsing {
    func parse(ocr: OCRRawResult) -> ParsedFields
}

/// 从 OCR 原文里抽出的字段。确认不了的保持 nil，不补全。
struct ParsedFields: Equatable {
    var name: String?
    var company: String?
    var jobTitle: String?
    var mobile: String?
    var phone: String?
    var email: String?
    var website: String?
    var address: String?
}

/// 只使用 OCR 行里已经出现的文字。传真不写入 phone。
struct BusinessCardFieldParser: BusinessCardFieldParsing {
    func parse(ocr: OCRRawResult) -> ParsedFields {
        let lines = ocr.lines.map(PreparedLine.init)
        var fields = ParsedFields()
        fields.email = firstEmail(in: lines)
        fields.website = firstWebsite(in: lines)
        let numbers = phoneNumbers(in: lines)
        fields.mobile = numbers.mobile
        fields.phone = numbers.phone

        let identity = lines.filter { !isContactLine($0) }
        fields.address = identity.first(where: { isAddress($0.value) })?.value
        let withoutAddress = identity.filter { !isAddress($0.value) && !isDepartment($0.value) }
        fields.jobTitle = withoutAddress.first(where: { isJobTitle($0.value) })?.value
        let withoutJob = withoutAddress.filter { !isJobTitle($0.value) }
        fields.company = bestCompany(in: withoutJob)
        fields.name = bestName(in: withoutJob)
        return fields
    }
}

private struct PreparedLine {
    var text: String
    var value: String
    var midY: CGFloat

    init(_ line: OCRLine) {
        text = FieldText.normalize(line.text)
        value = FieldText.stripLabels(text)
        midY = line.boundingBox.midY
    }
}

private enum PhoneRole {
    case mobile
    case phone
    case fax
    case unknown
}

private extension BusinessCardFieldParser {
    func firstEmail(in lines: [PreparedLine]) -> String? {
        for line in lines {
            if let email = FieldText.firstMatch(FieldText.emailPattern, in: line.text) {
                return email
            }
        }
        return nil
    }

    func firstWebsite(in lines: [PreparedLine]) -> String? {
        for line in lines {
            let withoutEmail = FieldText.removingEmails(line.text)
            if let site = FieldText.firstMatch(FieldText.websitePattern, in: withoutEmail) {
                return FieldText.trimTrailingPunctuation(site)
            }
        }
        return nil
    }

    func phoneNumbers(in lines: [PreparedLine]) -> (mobile: String?, phone: String?) {
        var mobile: String?
        var phone: String?
        for line in lines {
            guard let number = FieldText.firstMatch(FieldText.phonePattern, in: line.text) else { continue }
            switch phoneRole(of: line.text) {
            case .fax:
                continue
            case .mobile:
                if mobile == nil { mobile = number }
            case .phone:
                if phone == nil { phone = number }
            case .unknown:
                if FieldText.isChineseMobile(number) {
                    if mobile == nil { mobile = number }
                } else if phone == nil {
                    phone = number
                }
            }
        }
        return (mobile, phone)
    }

    func phoneRole(of text: String) -> PhoneRole {
        if FieldText.containsToken(text, "fax") || text.contains("传真") {
            return .fax
        }
        if FieldText.containsToken(text, "mobile") || text.contains("手机") || text.contains("移动") {
            return .mobile
        }
        if FieldText.containsToken(text, "office") || FieldText.containsToken(text, "tel") || text.contains("电话") {
            return .phone
        }
        return .unknown
    }

    func isContactLine(_ line: PreparedLine) -> Bool {
        if line.text.contains("@") { return true }
        if FieldText.firstMatch(FieldText.phonePattern, in: line.text) != nil { return true }
        if FieldText.firstMatch(FieldText.websitePattern, in: FieldText.removingEmails(line.text)) != nil { return true }
        if FieldText.containsToken(line.text, "postal") || line.text.contains("邮编") { return true }
        if FieldText.containsToken(line.text, "fax") || line.text.contains("传真") { return true }
        return false
    }

    func isAddress(_ value: String) -> Bool {
        guard value.contains(where: \.isNumber) else { return false }
        if FieldText.containsAny(value, FieldText.addressKeywordsCN) { return true }
        return FieldText.addressKeywordsEN.contains { FieldText.containsToken(value, $0) }
    }

    func isDepartment(_ value: String) -> Bool {
        if value.localizedStandardContains("school of") || value.localizedStandardContains("department") {
            return true
        }
        if value.contains("/") && value.contains("学院") { return true }
        let suffixes = ["部", "中心", "门店", "处", "组"]
        return suffixes.contains { value.hasSuffix($0) }
    }

    func isJobTitle(_ value: String) -> Bool {
        guard !isAddress(value), !value.contains("@") else { return false }
        let words = value.split(separator: " ")
        guard !words.isEmpty, words.count <= 6 else { return false }
        if FieldText.containsAny(value, FieldText.jobKeywordsCN) { return true }
        return FieldText.jobKeywordsEN.contains { FieldText.containsToken(value, $0) }
    }

    func bestCompany(in lines: [PreparedLine]) -> String? {
        let candidates = lines.compactMap { line -> (name: String, score: Int, cjk: Bool, midY: CGFloat)? in
            let name = companyName(from: line.value)
            guard let score = companyScore(name) else { return nil }
            return (name, score, FieldText.containsCJK(name), line.midY)
        }
        return candidates.max { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            if lhs.cjk != rhs.cjk { return rhs.cjk }
            return lhs.midY < rhs.midY
        }?.name
    }

    func companyName(from value: String) -> String {
        guard FieldText.containsLatin(value),
              let cjk = FieldText.leadingCJKPhrase(value),
              companyScore(cjk) != nil
        else {
            return value
        }
        return cjk
    }

    func companyScore(_ value: String) -> Int? {
        if isDepartment(value) || isAddress(value) || isJobTitle(value) { return nil }
        var score = 0
        if FieldText.containsAny(value, FieldText.strongCompanyCN) { score += 3 }
        if FieldText.strongCompanyEN.contains(where: { FieldText.containsToken(value, $0) }) { score += 3 }
        if FieldText.containsAny(value, FieldText.weakCompanyCN) { score += 1 }
        if FieldText.weakCompanyEN.contains(where: { FieldText.containsToken(value, $0) }) { score += 1 }
        return score > 0 ? score : nil
    }

    func bestName(in lines: [PreparedLine]) -> String? {
        let candidates = lines.filter { line in
            line.midY >= 2.0 / 3.0 && isPersonalName(line.value)
        }
        return candidates.max(by: { $0.midY < $1.midY })?.value
    }

    func isPersonalName(_ value: String) -> Bool {
        if value.contains("@") || value.contains(where: \.isNumber) { return false }
        if isDepartment(value) || isJobTitle(value) || isAddress(value) || companyScore(value) != nil {
            return false
        }
        if FieldText.isChinesePersonalName(value) { return true }
        return FieldText.isEnglishPersonalName(value)
    }
}

private enum FieldText {
    static let emailPattern = #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
    static let websitePattern = #"(?i)(?:https?://|www\.)[A-Za-z0-9.\-]+\.[A-Za-z]{2,}|(?<![@A-Za-z0-9.])[A-Za-z0-9][A-Za-z0-9.\-]*\.(?:com|cn|edu|org|net|example)\b"#
    static let phonePattern = #"\+\d{1,3}(?:[\s\-]\d{2,4}){2,3}"#

    static let addressKeywordsCN = ["省", "市", "区", "县", "路", "街", "巷", "道", "号"]
    static let addressKeywordsEN = ["street", "road", "avenue", "way", "lane"]

    static let jobKeywordsCN = ["教授", "经理", "总监", "工程师", "顾问", "建筑师", "分析师", "主管", "设计师", "店长", "主理人", "译员", "研究员", "主任"]
    static let jobKeywordsEN = ["professor", "manager", "director", "engineer", "ceo", "cto", "lead", "scientist", "architect", "editor", "associate", "founder", "counsel", "producer", "designer", "analyst"]

    static let strongCompanyCN = ["大学", "公司", "集团", "事务所", "工作室", "实验室"]
    static let weakCompanyCN = ["科技", "物流", "教育", "建筑", "文化", "咨询", "制造", "设计", "医疗", "软件", "资本", "媒体", "会计", "会展", "翻译", "零售"]
    static let strongCompanyEN = ["inc", "ltd", "corp", "llc", "university"]
    static let weakCompanyEN = ["technologies", "consulting", "labs", "studio", "analytics", "capital", "media", "design", "health", "software", "freight", "press", "legal"]

    static let labelPrefixes = [
        "手机 Mobile", "电话 Office", "传真 Fax", "邮箱 Email", "网址 Web", "地址 Address",
        "Mobile", "Office", "Fax", "Email", "Web", "Address", "Postal",
        "手机", "电话", "传真", "邮箱", "网址", "地址", "邮编",
    ].sorted { $0.count > $1.count }

    static func normalize(_ text: String) -> String {
        var result = text
        for dash in ["‐", "‑", "–", "—", "−"] {
            result = result.replacingOccurrences(of: dash, with: "-")
        }
        result = result.replacingOccurrences(of: "＋", with: "+")
        return result.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func stripLabels(_ text: String) -> String {
        var value = text
        var didStrip = true
        while didStrip {
            didStrip = false
            for prefix in labelPrefixes where value.hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count))
                if value.hasPrefix(":") || value.hasPrefix("：") {
                    value = String(value.dropFirst())
                }
                value = value.trimmingCharacters(in: .whitespaces)
                didStrip = true
                break
            }
        }
        return value
    }

    static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }

    static func removingEmails(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: emailPattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
    }

    static func trimTrailingPunctuation(_ text: String) -> String {
        var value = text
        while let last = value.last, ".,;，。".contains(last) {
            value.removeLast()
        }
        return value
    }

    static func containsToken(_ text: String, _ token: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: token)
        return firstMatch("(?i)(?<![A-Za-z])\(escaped)(?![A-Za-z])", in: text) != nil
    }

    static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    static func containsCJK(_ text: String) -> Bool {
        text.contains(where: isCJK)
    }

    static func containsLatin(_ text: String) -> Bool {
        text.contains(where: \.isLetter) && text.contains { $0.isASCII && $0.isLetter }
    }

    static func isCJK(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { (0x4E00...0x9FFF).contains($0.value) }
    }

    static func leadingCJKPhrase(_ text: String) -> String? {
        let phrase = text.prefix { isCJK($0) || $0 == "·" || $0 == " " }
        let trimmed = phrase.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func isChineseMobile(_ raw: String) -> Bool {
        let digits = raw.filter(\.isNumber)
        let national = digits.hasPrefix("86") ? String(digits.dropFirst(2)) : digits
        return national.count == 11 && national.hasPrefix("1")
    }

    static func isChinesePersonalName(_ value: String) -> Bool {
        let characters = Array(value)
        guard (2...4).contains(characters.count) else { return false }
        return characters.allSatisfy(isCJK)
    }

    static func isEnglishPersonalName(_ value: String) -> Bool {
        let words = value.split(separator: " ")
        guard (2...4).contains(words.count) else { return false }
        return words.allSatisfy { word in
            firstMatch(#"^[A-Z][a-z]+(?:[-'][A-Z][a-z]+)?$"#, in: String(word)) == String(word)
        }
    }
}
