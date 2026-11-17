import SwiftUI

@main
struct DDMUpdateCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView(model: appDelegate.preferences)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") { appDelegate.showPreferences() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
