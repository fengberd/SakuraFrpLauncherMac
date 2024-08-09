import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: LauncherModel

    @State var currentTab = TabItemView.Tabs.settings
    @State var logScrollPosition: UUID? = nil

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                sidebar
                content.transition(.opacity.animation(.default.speed(2.5)))
            }
            if let popup = model.popupContent {
                Color.black.opacity(0.3).edgesIgnoringSafeArea(.all)
                popup
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.background))
                    .shadow(radius: 16)
            }
        }
    }

    var sidebar: some View {
        List {
            LogoView()
            TabItemView(title: "隧道", iconImage: "server.rack", target: .tunnel, current: $currentTab)
                .disabled(!model.connected || model.user.status != .loggedIn)
            TabItemView(title: "日志", iconImage: "doc.text", target: .log, current: $currentTab)
            TabItemView(title: "设置", iconImage: "gearshape", target: .settings, current: $currentTab)
            TabItemView(title: "关于", iconImage: "info.circle", target: .about, current: $currentTab)
        }
        .frame(width: 180)
        .listStyle(SidebarListStyle())
    }

    @ViewBuilder
    var content: some View {
        VStack(spacing: 0) {
            switch currentTab {
            case .tunnel:
                TunnelTab()
            case .log:
                LogTab(lastScrollOffset: $logScrollPosition)
            case .settings:
                SettingsTab()
            case .about:
                AboutTab()
            }
            if !model.connected {
                Text("未连接到守护进程, 大部分功能将不可用, 请尝试重启启动器")
                    .font(.system(size: 18))
                    .padding(4)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
            } else {
                updateBar
            }
        }
    }

    @ViewBuilder
    var updateBar: some View {
        if model.update.status == .ready {
            Button(action: {
                if model.update.updateURL.isEmpty {
                    Task {
                        model.rpcWithAlert {
                            _ = try await model.RPC?.confirmUpdate(model.rpcEmpty)
                            NSApplication.shared.terminate(self)
                        }
                    }
                } else {
                    NSWorkspace.shared.open(URL(string: model.update.updateURL)!)
                }
            }) {
                Text(model.update.updateURL.isEmpty ? "更新准备完成, 点此进行更新" : "有更新可用, 点击此处打开下载页面")
                    .font(.system(size: 18))
                    .padding(4)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0, green: 0.5, blue: 0.5))
            }.buttonStyle(PlainButtonStyle())
        } else if model.update.status == .downloading {
            Text("下载更新中... \(Double(model.update.downloadCompleted) / 1_048_576, specifier: "%.2f")MiB/\(Double(model.update.downloadTotal) / 1_048_576, specifier: "%.2f")MiB")
                .font(.system(size: 18))
                .padding(4)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0, green: 0.5, blue: 0.5))
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewLayout(.fixed(width: 782, height: 500))
            .environmentObject(LauncherModel_Preview() as LauncherModel)
    }
}
#endif
