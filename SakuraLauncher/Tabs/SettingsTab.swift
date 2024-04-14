import Kingfisher
import SwiftUI

struct SettingsTab: View {
    @EnvironmentObject var model: LauncherModel

    @State var token = ""

    @State var pendingLogin = false
    @State var pendingRefresh = false
    @State var checkingUpdate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                accountOpts
                Divider()
                launcherOpts
                Divider()
                serviceOpts
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 24)
    }

    var accountOpts: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.user.status == .loggedIn {
                HStack {
                    KFImage(URL(string: model.user.avatar)!)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 8) {
                        Text("#\(model.user.id) \(model.user.name)")
                            .font(.title3)
                        Text("\(model.user.group.name) \(model.user.speed)")
                            .font(.subheadline)
                    }
                    .padding(.leading, 12)

                    Button("刷新节点列表") {
                        pendingRefresh = true
                        model.rpcWithAlert({
                            _ = try await model.RPC?.reloadNodes(.with {
                                $0.force = true
                            })
                        }) { pendingRefresh = false }
                    }
                    .padding(.leading)
                    .disabled(pendingRefresh)

                    Button("退出") {
                        pendingLogin = true
                        model.rpcWithAlert({
                            _ = try await model.RPC?.logout(model.rpcEmpty)
                        }) { pendingLogin = false }
                    }
                    .padding(.leading)
                    .disabled(pendingLogin)
                }
                .disabled(!model.connected)
            } else {
                HStack(spacing: 16) {
                    Text("登录账户:")
                    TextField("访问密钥", text: model.user.status == .noLogin ? $token : .constant("****************"))
                        .frame(width: 200)
                    Button(model.user.status == .pending ? "登录中..." : "登录") {
                        pendingLogin = true
                        model.rpcWithAlert({
                            _ = try await model.RPC?.login(.with {
                                $0.token = token
                            })
                        }) { pendingLogin = false }
                    }
                    .disabled(pendingLogin)
                }
                .disabled(!model.connected || model.user.status == .pending)
            }
        }
    }

    var launcherOpts: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("启动器").font(.title2)
            HStack {
                Text("隧道状态通知")
                Menu(model.notificationMode == 0 ? "显示所有" : model.notificationMode == 1 ? "隐藏所有" : "隐藏启动成功") {
                    Button("显示所有", action: { model.notificationMode = 0 })
                    Button("隐藏所有", action: { model.notificationMode = 1 })
                    Button("隐藏启动成功", action: { model.notificationMode = 2 })
                }
                .frame(width: 150)
            }
            HStack(spacing: 16) {
                Toggle("登录时启动守护进程", isOn: $model.launchAtLogin)
                    .toggleStyle(SwitchToggleStyle())
                Image(systemName: "questionmark.circle")
                    .help("在登录时自动启动守护进程和隧道 (不包含启动器界面)\n如需自动打开启动器界面请到系统设置里添加")
                    .font(.system(size: 16))
            }
        }
    }

    var serviceOpts: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("核心服务").font(.title2)
            Toggle("绕过系统代理", isOn: $model.bypassProxy)
                .toggleStyle(SwitchToggleStyle())
                .disabled(!model.connected)
            HStack(spacing: 16) {
                Toggle("自动检查更新", isOn: $model.checkUpdate)
                    .toggleStyle(SwitchToggleStyle())
                    .disabled(!model.connected)
                Button("立即检查") {
                    checkingUpdate = true
                    model.rpcWithAlert({
                        _ = try await model.RPC?.checkUpdate(model.rpcEmpty)
                        if model.update.status == .noUpdate {
                            model.showAlert("当前已是最新版本", "没有可用更新")
                        }
                    }) { checkingUpdate = false }
                }
                .disabled(!model.connected || !model.checkUpdate || checkingUpdate)
            }
            HStack {
                Text("frpc 日志等级")
                Menu(model.frpcLogLevel == "trace" ? "跟踪 [Trace]" : model.frpcLogLevel == "debug" ? "调试 [Debug]" : model.frpcLogLevel == "info" ? "信息 [Info]" : model.frpcLogLevel == "warn" ? "警告 [Warn]" :
                    model.frpcLogLevel == "error" ? "错误 [Error]" : ""
                ) {
                    Button("跟踪 [Trace]", action: { model.frpcLogLevel = "trace" })
                    Button("调试 [Debug]", action: { model.frpcLogLevel = "debug" })
                    Button("信息 [Info]", action: { model.frpcLogLevel = "info" })
                    Button("警告 [Warn]", action: { model.frpcLogLevel = "warn" })
                    Button("错误 [Error]", action: { model.frpcLogLevel = "error" })
                }
                .frame(width: 150)
            }
            Divider()
            HStack(spacing: 8) {
                Text("高级设置").font(.title2)
                Image(systemName: "exclamationmark.triangle")
                    .help("修改前请仔细阅读帮助文档, 如果您不清楚这些功能的作用, 请不要进行任何修改")
                    .font(.title2)
            }
            HStack(spacing: 16) {
                Toggle("强制使能 frpc TLS", isOn: $model.enableFrpcTls)
                    .toggleStyle(SwitchToggleStyle())
                    .disabled(!model.connected)
                Image(systemName: "questionmark.circle")
                    .help("使 frpc 全程使用 TLS 加密流量, 将有效增大 CPU 占用并显著提高延迟")
                    .font(.system(size: 16))
            }
            HStack(spacing: 16) {
                Toggle("启用远程管理", isOn: $model.enableRemoteManagement)
                    .toggleStyle(SwitchToggleStyle())
                    .disabled(!model.connected || model.config.remoteManagementKey != "SET")
                Image(systemName: "questionmark.circle")
                    .help("通过 Sakura Frp 管理启动器, 该功能由端到端加密保护, 启用前需先设置密码")
                    .font(.system(size: 16))
                Button("设置密码") {
                    model.showPopup(AnyView(RemoteConfigPopup()))
                }
            }
            HStack(spacing: 16) {
                Button("打开工作目录") {
                    model.rpcWithAlert {
                        _ = try await model.RPC?.openCWD(model.rpcEmpty)
                    }
                }
            }
        }
    }
}

#if DEBUG
struct SettingsTab_Previews: PreviewProvider {
    static var previews: some View {
        SettingsTab()
            .previewLayout(.fixed(width: 602, height: 500))
            .environmentObject(LauncherModel_Preview() as LauncherModel)
    }
}
#endif
