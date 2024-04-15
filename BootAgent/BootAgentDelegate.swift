import Cocoa

class BootAgentDelegate: NSObject, NSApplicationDelegate {
    let serviceBundle = "com.natfrp.launcher"

    func applicationDidFinishLaunching(_: Foundation.Notification) {
        if !NSWorkspace.shared.runningApplications
            .contains(where: { $0.bundleIdentifier == serviceBundle })
        {
            var url = Bundle.main.bundleURL
            url.deleteLastPathComponent()
            url.deleteLastPathComponent()
            url.deleteLastPathComponent()
            url.appendPathComponent("MacOS/natfrp-service.app")

            let opts = NSWorkspace.OpenConfiguration()
            opts.activates = false
            opts.addsToRecentItems = false

            NSWorkspace.shared.openApplication(at: url, configuration: opts, completionHandler: nil)
        }
        NSApplication.shared.terminate(self)
    }
}
