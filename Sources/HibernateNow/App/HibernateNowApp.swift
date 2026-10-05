import AppKit
import SwiftUI

@main
struct HibernateNowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = PowerManager()

    var body: some Scene {
        WindowGroup("电源管理") {
            ContentView()
                .environmentObject(manager)
                .frame(minWidth: 540, minHeight: 560)
                .onAppear { appDelegate.manager = manager }
        }
        .windowResizability(.contentSize)
    }
}
