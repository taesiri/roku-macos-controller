import SwiftUI

@main
struct RokuMenuBarApp: App {
    @StateObject private var viewModel = RokuViewModel()

    var body: some Scene {
        MenuBarExtra("Roku", systemImage: "tv") {
            RokuMenuView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
