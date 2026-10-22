import AppKit
import SwiftUI

@main
struct AstraDialApp: App {
    @State private var model = AppModel()

    init() {
        // A bundled build sets LSUIElement; this also hides the Dock icon under `swift run`.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            Image(systemName: model.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}
