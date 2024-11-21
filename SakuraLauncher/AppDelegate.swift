import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    var isPreview = true

    var model: LauncherModel?

    var mainWindow: NSWindow!
    var statusBarMenu: NSMenu!
    var statusBarItem: NSStatusItem!

    func applicationDidFinishLaunching(_: Foundation.Notification) {
        if isPreview {
            return
        }

        if let running = NSWorkspace.shared.runningApplications
            .first(where: { item in item.bundleIdentifier == Bundle.main.bundleIdentifier && item.processIdentifier != getpid() })
        {
            if !running.terminate(), !running.forceTerminate() {
                let alert = NSAlert()
                alert.messageText = "启动器已在运行"
                alert.informativeText = "请在菜单栏寻找启动器图标, 不要重复开启启动器"
                alert.alertStyle = NSAlert.Style.informational
                alert.addButton(withTitle: "好的")
                alert.runModal()

                NSApplication.shared.terminate(self)
            }

            let alert = NSAlert()
            alert.messageText = "请不要重复开启启动器"
            alert.informativeText = "重复的实例已被强制结束"
            alert.alertStyle = NSAlert.Style.informational
            alert.addButton(withTitle: "好的")
            alert.runModal()
        }

        UNUserNotificationCenter.current().delegate = self

        mainWindow = NSApplication.shared.windows[0]
        if let window = mainWindow {
            window.delegate = self
            window.isMovableByWindowBackground = true
            window.standardWindowButton(.zoomButton)!.isHidden = true
        }

        showWindow()

        statusBarMenu = NSMenu()
        statusBarMenu.delegate = self
        statusBarMenu.autoenablesItems = false
        statusBarMenu.addItem(withTitle: "隐藏", action: #selector(hideAction), keyEquivalent: "")
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(withTitle: "退出", action: #selector(exitAction), keyEquivalent: "q")
            .keyEquivalentModifierMask = [.command]
        statusBarMenu.addItem(withTitle: "彻底退出", action: #selector(exitFullAction), keyEquivalent: "q")
            .keyEquivalentModifierMask = [.command, .option]

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusBarItem.button {
            btn.image = NSImage(imageLiteralResourceName: "StatusBarIcon")
            btn.image!.isTemplate = true
            btn.action = #selector(statusAction)
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    func showWindow() {
        NSApplication.shared.setActivationPolicy(.regular)
        mainWindow?.orderFront(self)
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let m = statusBarMenu {
            m.items[0].title = "隐藏"
            m.items[0].action = #selector(hideAction)
        }
    }

    func hideWindow() {
        NSApplication.shared.setActivationPolicy(.accessory)
        mainWindow?.orderOut(self)

        if let m = statusBarMenu {
            m.items[0].title = "显示"
            m.items[0].action = #selector(showAction)
        }
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        hideWindow()
        return false
    }

    @objc func statusAction(sender _: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == NSEvent.EventType.rightMouseUp {
            statusBarItem.menu = statusBarMenu
            statusBarItem.button?.performClick(nil)
        } else {
            showWindow()
        }
    }

    @objc func menuDidClose(_: NSMenu) {
        statusBarItem.menu = nil // remove menu so button works as before
    }

    @objc func showAction(_: AnyObject?) {
        showWindow()
    }

    @objc func hideAction(_: AnyObject?) {
        hideWindow()
    }

    @objc func exitAction(_: AnyObject?) {
        NSApplication.shared.terminate(self)
    }

    @MainActor @objc func exitFullAction(_: AnyObject?) {
        statusBarMenu.items[3].isEnabled = false
        model!.daemon.fullShutdown()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
