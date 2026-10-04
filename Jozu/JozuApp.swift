import SwiftUI

@main
struct JozuApp: App {
    @State private var settings = AppSettings.load()

    var body: some Scene {
        WindowGroup {
            ChatView()
                .environment(settings)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 760, height: 860)

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(settings)
                .frame(minWidth: 420, minHeight: 360)
        }
        #endif
    }
}
