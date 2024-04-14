import SwiftUI

@main
struct SakuraLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var model = LauncherModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 725, idealWidth: 782, minHeight: 400, idealHeight: 500)
                .navigationTitle("Sakura Launcher")
                .environmentObject(model)
                .onAppear {
                    appDelegate.model = model
                    appDelegate.isPreview = false
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())

        WindowGroup(id: "create-tunnel", for: String.self) { editTunnel in
            CreateTunnelPopup(editTunnel: editTunnel)
                .frame(minWidth: 725, idealWidth: 880, maxWidth: 1000, minHeight: 400, idealHeight: 600)
                .environmentObject(model)
                .navigationTitle(editTunnel.wrappedValue == nil ? "创建隧道" : "编辑隧道")
        }
        .windowResizability(.contentSize)
    }
}
