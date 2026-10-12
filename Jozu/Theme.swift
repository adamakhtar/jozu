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
    var isFocused: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty && !isFocused {
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
            selectedUTF16Range: selectedUTF16Range,
            isFocused: isFocused
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
private final class ComposerScrollView: NSScrollView {
    override var acceptsFirstResponder: Bool { false }

    override func becomeFirstResponder() -> Bool {
        if let text = documentView as? NSTextView {
            window?.makeFirstResponder(text)
        }
        return false
    }
}

private final class ComposerNSTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }
}

private struct MacComposerTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    var selectedUTF16Range: Binding<NSRange>?
    var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedUTF16Range: selectedUTF16Range)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = ComposerScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.focusRingType = .none
        scroll.autoresizingMask = [.width, .height]

        let textView = ComposerNSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = NSFont.systemFont(ofSize: JozuComposerMetrics.fontSize)
        textView.textColor = NSColor(red: 0.07, green: 0.06, blue: 0.05, alpha: 1)
        textView.insertionPointColor = NSColor(red: 0.07, green: 0.06, blue: 0.05, alpha: 1)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(
            width: JozuComposerMetrics.padding,
            height: JozuComposerMetrics.padding
        )
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scroll.contentSize.width,
            height: .greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.focusRingType = .none
        context.coordinator.lastEmitted = text

        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.text = $text
        coordinator.selectedUTF16Range = selectedUTF16Range
        guard let textView = scroll.documentView as? NSTextView else { return }

        textView.isEditable = isEditable
        textView.font = NSFont.systemFont(ofSize: JozuComposerMetrics.fontSize)
        textView.textContainerInset = NSSize(
            width: JozuComposerMetrics.padding,
            height: JozuComposerMetrics.padding
        )
        textView.textContainer?.lineFragmentPadding = 0
        if scroll.contentSize.width > 0 {
            textView.textContainer?.containerSize = NSSize(
                width: scroll.contentSize.width,
                height: .greatestFiniteMagnitude
            )
        }

        if isFocused, let window = scroll.window, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
        }

        // Dictation uses marked text. Resetting `string` or the selection
        // during that session drops the utterance — caret blinks, no words.
        if textView.hasMarkedText() {
            return
        }

        if textView.string == text {
            coordinator.lastEmitted = text
            return
        }

        let isFirst = textView.window?.firstResponder === textView
        let swiftUIChangedIndependently = text != coordinator.lastEmitted
            && textView.string == coordinator.lastEmitted
        if !isFirst || swiftUIChangedIndependently {
            coordinator.apply(text, to: textView)
            if !isFirst,
               let range = selectedUTF16Range?.wrappedValue,
               range.location != NSNotFound,
               NSMaxRange(range) <= (text as NSString).length {
                textView.setSelectedRange(range)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var selectedUTF16Range: Binding<NSRange>?
        var lastEmitted = ""
        private var isApplying = false

        init(text: Binding<String>, selectedUTF16Range: Binding<NSRange>?) {
            self.text = text
            self.selectedUTF16Range = selectedUTF16Range
        }

        func apply(_ value: String, to textView: NSTextView) {
            isApplying = true
            textView.string = value
            lastEmitted = value
            isApplying = false
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplying, let textView = notification.object as? NSTextView else { return }
            lastEmitted = textView.string
            text.wrappedValue = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplying, let textView = notification.object as? NSTextView else { return }
            if textView.hasMarkedText() { return }
            selectedUTF16Range?.wrappedValue = textView.selectedRange()
        }
    }
}
#endif
