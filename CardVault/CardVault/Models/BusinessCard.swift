import Foundation
import SwiftData

/// 用户确认后的名片记录。联系人字段为空表示名片上没有这项信息。
@Model
final class BusinessCard {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var originalImageData: Data?
    @Attribute(.externalStorage) var processedImageData: Data?
    var name: String?
    var company: String?
    var jobTitle: String?
    var mobile: String?
    var phone: String?
    var email: String?
    var website: String?
    var address: String?
    var notes: String?
    var createdAt: Date

    /// 多对多。删除名片只解除与标签的关联，不删除标签。
    @Relationship(deleteRule: .nullify, inverse: \Tag.cards)
    var tags: [Tag]

    /// 一对多。删除名片时一并删除它的 OCR 原文记录。
    @Relationship(deleteRule: .cascade, inverse: \OCRResult.card)
    var ocrResults: [OCRResult]

    init(
        id: UUID = UUID(),
        originalImageData: Data? = nil,
        processedImageData: Data? = nil,
        name: String? = nil,
        company: String? = nil,
        jobTitle: String? = nil,
        mobile: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        tags: [Tag] = [],
        ocrResults: [OCRResult] = []
    ) {
        self.id = id
        self.originalImageData = originalImageData
        self.processedImageData = processedImageData
        self.name = name
        self.company = company
        self.jobTitle = jobTitle
        self.mobile = mobile
        self.phone = phone
        self.email = email
        self.website = website
        self.address = address
        self.notes = notes
        self.createdAt = createdAt
        self.tags = tags
        self.ocrResults = ocrResults
    }
}
