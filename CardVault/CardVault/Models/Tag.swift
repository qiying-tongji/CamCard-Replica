import Foundation
import SwiftData

/// 名片标签。同名标签只保留一条。
@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String

    /// 反向关系。删除标签只解除与名片的关联，不删除名片。
    var cards: [BusinessCard]

    init(
        id: UUID = UUID(),
        name: String,
        cards: [BusinessCard] = []
    ) {
        self.id = id
        self.name = name
        self.cards = cards
    }
}
