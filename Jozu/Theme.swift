import SwiftUI

enum JozuTheme {
    static let ink = Color(red: 0.07, green: 0.06, blue: 0.05)
    static let muted = Color(red: 0.32, green: 0.28, blue: 0.24)
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let card = Color(red: 1.0, green: 0.99, blue: 0.97)
    static let line = Color(red: 0.84, green: 0.80, blue: 0.74)
    static let vermillion = Color(red: 0.72, green: 0.22, blue: 0.16)
    static let userInk = Color.white
}

struct JozuComposerField: View {
    @Binding var text: String
    var placeholder: String
    var isEditable: Bool = true
    var minHeight: CGFloat = 80
    var maxHeight: CGFloat = 176

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 16))
                    .foregroundStyle(JozuTheme.muted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }

            if isEditable {
                TextEditor(text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(JozuTheme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            } else if !text.isEmpty {
                ScrollView {
                    Text(text)
                        .font(.system(size: 16))
                        .foregroundStyle(JozuTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .frame(minHeight: minHeight, maxHeight: maxHeight, alignment: .top)
        .background(JozuTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(JozuTheme.line, lineWidth: 1)
        )
    }
}
