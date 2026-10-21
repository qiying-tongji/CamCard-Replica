import SwiftData
import SwiftUI
import UIKit

/// 核对识别出的 8 个字段。取消回到选图，保存写入名片夹。
struct ConfirmView: View {
    let originalImage: UIImage
    let processedImage: UIImage
    let ocrRawText: String
    let onCancel: () -> Void
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var draft: CardFieldDraft
    @State private var isSaving = false
    @State private var saveError: String?

    init(
        fields: ParsedFields,
        originalImage: UIImage,
        processedImage: UIImage,
        ocrRawText: String,
        onCancel: @escaping () -> Void,
        onSaved: @escaping () -> Void
    ) {
        self.originalImage = originalImage
        self.processedImage = processedImage
        self.ocrRawText = ocrRawText
        self.onCancel = onCancel
        self.onSaved = onSaved
        _draft = State(initialValue: CardFieldDraft(fields: fields))
    }

    var body: some View {
        VStack(spacing: 0) {
            CardFieldForm(draft: $draft)
            if let saveError {
                Text(saveError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("取消")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("保存")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
            .padding()
        }
        .navigationTitle("核对名片信息")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let originalData = await encoded(originalImage)
        let processedData = await encoded(processedImage)
        let card = BusinessCard(
            originalImageData: originalData,
            processedImageData: processedData,
            name: nil,
            company: nil,
            jobTitle: nil,
            mobile: nil,
            phone: nil,
            email: nil,
            website: nil,
            address: nil
        )
        draft.apply(to: card)
        let ocr = OCRResult(rawText: ocrRawText.isEmpty ? nil : ocrRawText)
        modelContext.insert(card)
        modelContext.insert(ocr)
        ocr.card = card

        do {
            try modelContext.save()
            onSaved()
        } catch {
            modelContext.delete(card)
            saveError = "保存失败"
        }
    }

    private func encoded(_ image: UIImage) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            image.jpegData(compressionQuality: 0.85) ?? image.pngData()
        }.value
    }
}
