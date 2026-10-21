import Foundation
import SwiftData

/// 一次 OCR 的原始文本。与名片上已确认的字段分开保存。
@Model
final class OCRResult {
    @Attribute(.unique) var id: UUID
    var rawText: String?
    var createdAt: Date

    /// 反向关系。删除这条原文记录不会删除名片。
    var card: BusinessCard?

    init(
        id: UUID = UUID(),
        rawText: String? = nil,
        createdAt: Date = .now,
        card: BusinessCard? = nil
    ) {
        self.id = id
        self.rawText = rawText
        self.createdAt = createdAt
        self.card = card
    }
}
