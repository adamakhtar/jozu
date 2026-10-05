import Foundation

struct PeekTarget: Identifiable, Hashable, Sendable {
    var id: String { bundleID }
    var bundleID: String
    var name: String
    var pid: pid_t
}

struct PendingPeek: Equatable, Sendable {
    var appName: String
    var bundleID: String
    var text: String
}

enum PeekError: LocalizedError {
    case unsupported
    case notTrusted
    case notAllowlisted
    case appGone
    case noFocus
    case noSelection
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "Peek is Mac-only."
        case .notTrusted:
            return "Allow Jozu in System Settings → Privacy & Security → Accessibility."
        case .notAllowlisted:
            return "That app is not on this session’s allowlist."
        case .appGone:
            return "That app is no longer running."
        case .noFocus:
            return "Could not find a focused field in that app. Click into the text, then peek again."
        case .noSelection:
            return "No selected text. Select the sentence in that app, then peek again."
        case .failed(let message):
            return message
        }
    }
}

#if os(macOS)
import AppKit
import ApplicationServices

enum AXPeek {
    static let maxCharacters = 4000
    static let ownBundleID = Bundle.main.bundleIdentifier ?? "com.adamakhtar.jozu"

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func promptForTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) { return }
        }
    }

    static func runningApps() -> [PeekTarget] {
        NSWorkspace.shared.runningApplications
            .compactMap { target(from: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func target(from app: NSRunningApplication) -> PeekTarget? {
        guard app.activationPolicy == .regular, !app.isTerminated else { return nil }
        guard let bundleID = app.bundleIdentifier, bundleID != ownBundleID else { return nil }
        return PeekTarget(
            bundleID: bundleID,
            name: app.localizedName ?? bundleID,
            pid: app.processIdentifier
        )
    }

    static func running(bundleID: String) -> PeekTarget? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .compactMap(target(from:))
            .first
    }

    static func selectedText(in target: PeekTarget, allowlist: Set<String>) throws -> String {
        guard isTrusted else { throw PeekError.notTrusted }
        guard allowlist.contains(target.bundleID) else { throw PeekError.notAllowlisted }
        guard let live = running(bundleID: target.bundleID) else { throw PeekError.appGone }

        let app = AXUIElementCreateApplication(live.pid)
        var focused: CFTypeRef?
        let focusStatus = AXUIElementCopyAttributeValue(
            app,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
        guard focusStatus == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            throw PeekError.noFocus
        }
        let element = unsafeBitCast(focused, to: AXUIElement.self)

        var selected: CFTypeRef?
        let selectStatus = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selected
        )
        guard selectStatus == .success, let raw = selected as? String else {
            throw PeekError.noSelection
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw PeekError.noSelection }
        if trimmed.count <= maxCharacters { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxCharacters)
        return String(trimmed[..<end])
    }
}

@MainActor
final class PeekMonitor {
    var onChange: ((PeekTarget) -> Void)?
    nonisolated(unsafe) private var token: (any NSObjectProtocol)?

    init() {
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let target = AXPeek.target(from: app)
            else { return }
            Task { @MainActor in
                self?.onChange?(target)
            }
        }
    }

    deinit {
        if let token {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }
}
#endif
