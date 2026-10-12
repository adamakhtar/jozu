import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#endif

enum JozuTheme {
    static let ink = Color(red: 0.07, green: 0.06, blue: 0.05)
    static let muted = Color(red: 0.32, green: 0.28, blue: 0.24)
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.91)
    static let card = Color(red: 1.0, green: 0.99, blue: 0.97)
    static let line = Color(red: 0.84, green: 0.80, blue: 0.74)
    static let vermillion = Color(red: 0.72, green: 0.22, blue: 0.16)
    static let userInk = Color.white
}

enum JozuComposerMetrics {
    static let fontSize: CGFloat = 16
    static let padding: CGFloat = 12
}

struct JozuComposerField: View {
    @Binding var text: String
    var placeholder: String
    var isEditable: Bool = true
    var minHeight: CGFloat = 80
    var maxHeight: CGFloat = 176
    var selectedUTF16Range: Binding<NSRange>? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: JozuComposerMetrics.fontSize))
                    .foregroundStyle(JozuTheme.muted)
                    .padding(JozuComposerMetrics.padding)
                    .allowsHitTesting(false)
            }

            if isEditable {
                editor
            } else if !text.isEmpty {
                ScrollView {
                    Text(text)
                        .font(.system(size: JozuComposerMetrics.fontSize))
                        .foregroundStyle(JozuTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(JozuComposerMetrics.padding)
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

    @ViewBuilder
    private var editor: some View {
        #if os(macOS)
        MacComposerTextView(
            text: $text,
            isEditable: isEditable,
            selectedUTF16Range: selectedUTF16Range
        )
        #else
        TextEditor(text: $text)
            .font(.system(size: JozuComposerMetrics.fontSize))
            .foregroundStyle(JozuTheme.ink)
            .scrollContentBackground(.hidden)
            .padding(JozuComposerMetrics.padding)
        #endif
    }
}

#if os(macOS)
private struct MacComposerTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    var selectedUTF16Range: Binding<NSRange>?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedUTF16Range: selectedUTF16Range)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.focusRingType = .none

        let textView = scroll.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = NSFont.systemFont(ofSize: JozuComposerMetrics.fontSize)
        textView.textColor = NSColor(
            red: 0.07,
            green: 0.06,
            blue: 0.05,
            alpha: 1
        )
        textView.insertionPointColor = NSColor(
            red: 0.07,
            green: 0.06,
            blue: 0.05,
            alpha: 1
        )
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(
            width: JozuComposerMetrics.padding,
            height: JozuComposerMetrics.padding
        )
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.focusRingType = .none
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.selectedUTF16Range = selectedUTF16Range
        guard let textView = scroll.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            if let range = selectedUTF16Range?.wrappedValue,
               range.location != NSNotFound,
               NSMaxRange(range) <= (text as NSString).length {
                textView.setSelectedRange(range)
            }
        }
        textView.isEditable = isEditable
        textView.font = NSFont.systemFont(ofSize: JozuComposerMetrics.fontSize)
        textView.textContainerInset = NSSize(
            width: JozuComposerMetrics.padding,
            height: JozuComposerMetrics.padding
        )
        textView.textContainer?.lineFragmentPadding = 0
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var selectedUTF16Range: Binding<NSRange>?

        init(text: Binding<String>, selectedUTF16Range: Binding<NSRange>?) {
            self.text = text
            self.selectedUTF16Range = selectedUTF16Range
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            selectedUTF16Range?.wrappedValue = textView.selectedRange()
        }
    }
}
#endif
