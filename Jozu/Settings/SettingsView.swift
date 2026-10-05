import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Languages") {
                TextField("Native language", text: $settings.nativeLanguage)
                TextField("Target language", text: $settings.targetLanguage)
                Picker("Reply in", selection: $settings.replyLanguage) {
                    ForEach(ReplyLanguage.allCases) { language in
                        Text(language.label).tag(language)
                    }
                }
            }

            Section("Model") {
                TextField("Base URL", text: $settings.apiBaseURL)
                    .textContentType(.URL)
                TextField("Model", text: $settings.model)
                SecureField("API key", text: $settings.apiKey)
                Text("OpenAI-compatible. Required for chat, lessons, and review.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            #if os(macOS)
            Section("Peek") {
                Text("Selected text from apps you allow this session. Accessibility is required. Jozu never captures the whole screen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Settings")
        .preferredColorScheme(.light)
        .foregroundStyle(JozuTheme.ink)
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings.load())
        .frame(width: 460, height: 400)
}
