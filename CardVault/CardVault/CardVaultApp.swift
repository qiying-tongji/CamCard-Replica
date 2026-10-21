import SwiftData
import SwiftUI

/// 应用入口。名片夹读取本地数据；扫描页核对后保存到名片夹。
/// ModelContainer 把 BusinessCard、Tag、OCRResult 存到本地。
@main
struct CardVaultApp: App {
    @State private var selectedTab: AppTab = .cardHolder

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                CardListView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("名片夹", systemImage: "person.crop.rectangle.stack")
                    }
                    .tag(AppTab.cardHolder)

                ImportView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("扫描", systemImage: "viewfinder")
                    }
                    .tag(AppTab.scan)
            }
        }
        .modelContainer(for: [BusinessCard.self, Tag.self, OCRResult.self])
    }
}
