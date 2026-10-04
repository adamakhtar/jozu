import SwiftData
import SwiftUI

@main
struct JozuApp: App {
    @State private var settings = AppSettings.load()
    private let container = Persistence.makeContainer()

    var body: some Scene {
        WindowGroup {
            ChatView()
                .environment(settings)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
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
