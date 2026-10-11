import SwiftUI
import AppKit

@main
struct MyDashboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store: DashboardStore

    init() {
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--data-dir")
        let argumentDirectory: URL? = index.flatMap { $0 + 1 < args.count ? URL(fileURLWithPath: args[$0 + 1], isDirectory: true) : nil }
        let environmentDirectory = ProcessInfo.processInfo.environment["MYDASHBOARD_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        let directory = argumentDirectory ?? environmentDirectory
        _store = StateObject(wrappedValue: DashboardStore(directory: directory))
    }
    var body: some Scene {
        Window("Мой курс", id: "main") {
            ContentView().environmentObject(store).preferredColorScheme(.light)
        }
        .defaultSize(width: 1180, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Новая задача") { NotificationCenter.default.post(name: .newTask, object: nil) }.keyboardShortcut("n")
                Button("Новая цель") { NotificationCenter.default.post(name: .newGoal, object: nil) }.keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandMenu("Данные") {
                Button("Создать резервную копию…") { store.exportBackup() }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
extension Notification.Name {
    static let newTask = Notification.Name("MyDashboard.newTask")
    static let newGoal = Notification.Name("MyDashboard.newGoal")
}
