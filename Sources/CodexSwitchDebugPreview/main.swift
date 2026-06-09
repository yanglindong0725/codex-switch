import AppKit
import CodexSwitchPreview
import SwiftUI

final class DebugPreviewAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct CodexSwitchDebugPreviewApp: App {
    @NSApplicationDelegateAdaptor(DebugPreviewAppDelegate.self) private var appDelegate
    @StateObject private var model = SwitcherViewModel.preview()

    var body: some Scene {
        WindowGroup("Codex Switch Debug Preview") {
            ScrollView {
                CodexSwitchPopoverView(model: model)
                    .padding(28)
            }
            .frame(minWidth: 486, minHeight: 760)
        }
    }
}
