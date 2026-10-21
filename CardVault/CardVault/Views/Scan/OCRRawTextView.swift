import SwiftUI

/// 识别出的原文。只展示，不解析、不入库。
struct OCRRawTextView: View {
    let fullText: String

    var body: some View {
        ScrollView {
            Text(fullText.isEmpty ? "没有识别到文字" : fullText)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding()
        .navigationTitle("识别结果")
        .navigationBarTitleDisplayMode(.inline)
    }
}
