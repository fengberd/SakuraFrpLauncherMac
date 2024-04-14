import GRPC
import NIOPosix
import ServiceManagement
import SwiftUI
import UserNotifications

@MainActor class LauncherModel: ObservableObject {
    let preview: Bool

    var daemon: DaemonHost!

    init() {
        preview = false

        UserDefaults.standard.register(defaults: [
            "logTextWrapping": true,
            "notificationMode": 0,
        ])
        logTextWrapping = UserDefaults.standard.bool(forKey: "logTextWrapping")
        notificationMode = UserDefaults.standard.integer(forKey: "notificationMode")

        defer { notificationMode = notificationMode }

        logDateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"

        launchAtLogin = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd)
            .takeRetainedValue() as NSArray as! [[String: AnyObject]])
            .contains { $0["Label"] as! String == "com.natfrp.launcher.boot-agent" }

        daemon = DaemonHost(self)

        Task(priority: .background) {
            let loopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)
            defer { try? loopGroup.syncShutdownGracefully() }

            let sock = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "com.natfrp")!.path + "/Library/Caches/l.sock"

            while true {
                do {
                    try await connect(loopGroup, socket: sock)
                } catch let e {
                    print(e)
                }

                // Reset state
                user = .init()
                config = .init()
                update = .init()

                logs = .init()
                logFilters = .init()

                nodes = .init()
                tunnels = .init()

                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s, gRPC itself will wait for 1s
            }
        }
    }

    // MARK: - View: Generic

    @Published var popupContent: AnyView?

    func showAlert(_ text: String, _ title: String = "提示") {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = text
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    func showPopup(_ popup: AnyView) {
        withAnimation(.linear(duration: 0.1)) {
            popupContent = popup
        }
    }

    func closePopup() {
        withAnimation(.linear(duration: 0.1)) {
            popupContent = nil
        }
    }

    @Published var connected = false

    // MARK: - View: Launcher Settings

    @Published var logTextWrapping: Bool {
        willSet { UserDefaults.standard.setValue(newValue, forKey: "logTextWrapping") }
    }

    @Published var notificationMode: Int {
        willSet { UserDefaults.standard.setValue(newValue, forKey: "notificationMode") }
        didSet {
            if !preview && notificationMode != 1 {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { success, _ in
                    if !success {
                        self.showAlert("请到系统设置中打开 SakuraLauncher 的通知权限\n如果不想看到此提示请在启动器设置中将 \"隧道状态通知\" 设为 \"隐藏所有\"", "通知权限被禁用")
                    }
                }
            }
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            if !SMLoginItemSetEnabled("com.natfrp.launcher.boot-agent" as CFString, launchAtLogin) {
                showAlert("请检查是否开启了必要的权限", "启动项设置失败")
            }
        }
    }

    // MARK: - RPC

    let rpcEmpty = Empty()
    var RPC: NatfrpServiceAsyncClient?

    func initStream<T>(_ s: GRPCAsyncResponseStream<T>, _ cb: @escaping (T) -> Void) async throws -> Task<Void, Error> {
        var iter = s.makeAsyncIterator()
        guard let first = try await iter.next() else {
            throw GRPCStatus(code: .notFound, message: "Empty stream")
        }
        cb(first)

        return Task {
            while true {
                guard let r = try await iter.next() else {
                    return
                }
                cb(r)
            }
        }
    }

    func connect(_ loopGroup: MultiThreadedEventLoopGroup, socket: String) async throws {
        let channel = try GRPCChannelPool.with(
            target: .unixDomainSocket(socket),
            transportSecurity: .plaintext,
            eventLoopGroup: loopGroup
        ) {
            $0.connectionBackoff.retries = .none
            $0.connectionPool.maxWaitTime = .seconds(1)
        }
        defer { _ = channel.close() }

        let client = NatfrpServiceAsyncClient(channel: channel)

        RPC = client
        defer { RPC = nil }

        let tasks = try await [
            initStream(client.streamUpdate(rpcEmpty)) { [self] u in
                if u.hasUser {
                    user = u.user
                }
                if u.hasNodes {
                    Task {
                        for (k, n) in u.nodes.nodes {
                            nodes[k] = NodeModel(n)
                        }
                    }
                }
                if u.hasConfig {
                    config = u.config
                }
                if u.hasUpdate {
                    update = u.update
                }
            },
            initStream(client.streamLog(rpcEmpty)) { [self] l in
                if l.category == .unknown {
                    return
                } else if l.category == .alert {
                    if notificationMode == 0 ||
                        notificationMode == 2 && (l.level == .warn || l.level == .error || l.level == .fatal)
                    {
                        let content = UNMutableNotificationContent()
                        content.title = l.source
                        content.subtitle = l.data
                        content.sound = UNNotificationSound.default

                        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "StatusNotification", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)))
                    }
                    return
                }

                let entry = LogModel(source: l.source, data: l.data)
                if l.category == .frpc {
                    entry.source = "Tunnel/" + entry.source
                    if let match = LogModel.pattern.firstMatch(in: l.data, range: NSRange(l.data.startIndex..., in: l.data)) {
                        entry.time = l.data.groupOf(match, group: "Time")
                        entry.data = l.data.groupOf(match, group: "Content")
                        switch l.data.groupOf(match, group: "Level") {
                        case "W":
                            entry.level = .warning
                        case "E":
                            entry.level = .error
                        case "I":
                            fallthrough
                        default:
                            entry.level = .info
                        }
                    }
                } else {
                    entry.time = logDateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(l.time)))
                    switch l.level {
                    case .fatal:
                        entry.level = .fatal
                    case .error:
                        entry.level = .error
                    case .warn:
                        entry.level = .warning
                    case .debug:
                        entry.level = .debug
                    case .info:
                        fallthrough
                    default:
                        entry.level = .info
                    }
                }
                logs.append(entry)

                Task {
                    if logFilters[entry.source] == nil {
                        logFilters[entry.source] = 1
                    } else {
                        logFilters[entry.source]! += 1
                    }

                    while logs.count > 4096 {
                        let del = logs.remove(at: 0)
                        logFilters[del.source]! -= 1
                        if logFilters[del.source]! == 0 {
                            logFilters.removeValue(forKey: del.source)
                        }
                    }
                }
            },
            initStream(client.streamTunnels(rpcEmpty)) { [self] tu in
                switch tu.action {
                case .add:
                    tunnels.append(TunnelModel(tu.tunnel, launcher: self))
                case .clear:
                    tunnels = []
                case .delete:
                    tunnels.removeAll { $0.id == tu.tunnel.id }
                case .update:
                    Task {
                        if let idx = tunnels.firstIndex(where: { $0.id == tu.tunnel.id }) {
                            tunnels[idx].proto = tu.tunnel
                        }
                    }
                default:
                    break
                }
            },
        ]

        connected = true
        defer { connected = false }

        try await withThrowingTaskGroup(of: Void.self) { g in
            for task in tasks {
                g.addTask { try await task.value }
            }
            try await g.waitForAll()
        }
    }

    func rpcWithAlert(_ body: @escaping () async throws -> Void, _ finally: (() -> Void)? = nil) {
        Task {
            do {
                try await body()
            } catch {
                let alert = NSAlert(error: error)
                // check grpc response msg
                if let gErr = error as? GRPCStatus {
                    if gErr.code.rawValue == 2, let msg = gErr.message {
                        alert.messageText = msg
                    }
                }
                alert.runModal()
            }
            finally?()
        }
    }

    // MARK: - Tunnels & Nodes

    @Published var nodes: [Int32: NodeModel] = [:]

    @Published var tunnels: [TunnelModel] = []

    // MARK: - Logging

    @Published var logs: [LogModel] = []
    @Published var logFilters: [String: Int] = [:]

    private var logDateFormatter = DateFormatter()

    // MARK: - Service Config & Update

    @Published var user = User()

    @Published var config = ServiceConfig()
    @Published var update = SoftwareUpdate()

    var bypassProxy: Bool {
        get { config.bypassProxy }
        set {
            config.bypassProxy = newValue
            pushServiceConfig()
        }
    }

    var checkUpdate: Bool {
        get { config.updateInterval > 0 }
        set {
            config.updateInterval = newValue ? 86400 : -1
            pushServiceConfig()
        }
    }

    var frpcLogLevel: String {
        get { config.frpcLogLevel }
        set {
            config.frpcLogLevel = newValue
            pushServiceConfig()
        }
    }

    var enableFrpcTls: Bool {
        get { config.frpcForceTls }
        set {
            config.frpcForceTls = newValue
            pushServiceConfig()
        }
    }

    var enableRemoteManagement: Bool {
        get { config.remoteManagement && config.remoteManagementKey == "SET" }
        set {
            config.remoteManagement = newValue
            pushServiceConfig()
        }
    }

    func pushServiceConfig() {
        rpcWithAlert { [self] in
            _ = try await RPC?.updateConfig(config)
        }
    }

#if DEBUG
    init(preview: Bool) {
        assert(preview)
        self.preview = true
        logTextWrapping = true
        notificationMode = 1
        launchAtLogin = false
    }
#endif
}

#if DEBUG
class LauncherModel_Preview: LauncherModel {
    override init() {
        super.init(preview: true)
        nodes[1] = NodeModel(Node.with {
            $0.id = 1
            $0.name = "PA47 Node"
            $0.host = "1.2.3.4"
        })
        nodes[2] = NodeModel(Node.with {
            $0.id = 2
            $0.name = "LMAO BGP"
            $0.host = "66.66.66.66"
        })

        tunnels.append(TunnelModel(Tunnel.with {
            $0.id = 1
            $0.name = "SampleTunnel 1"
            $0.node = 1
            $0.type = "TCP"
            $0.remote = "2333"
            $0.localIp = "127.0.0.1"
            $0.localPort = 2333
        }, launcher: self))
        tunnels.append(TunnelModel(Tunnel.with {
            $0.id = 2
            $0.name = "SampleTunnel 2"
            $0.node = 2
            $0.type = "UDP"
            $0.remote = "2333"
            $0.localIp = "127.0.0.1"
            $0.localPort = 6666
        }, launcher: self))
        tunnels.append(TunnelModel(Tunnel.with {
            $0.id = 3
            $0.name = "SampleTunnel 3"
            $0.node = 3
            $0.type = "http"
            $0.localIp = "127.0.0.1"
            $0.localPort = 2333
        }, launcher: self))

        logs = [
            LogModel(source: "Service", data: "PA47", time: "2021/01/01 23:33:33", level: .info),
            LogModel(source: "Service", data: "PA47!!", time: "2021/01/01 23:33:33", level: .warning),
            LogModel(source: "Service", data: "PA47!!!", time: "2021/01/01 23:33:33", level: .error),
            LogModel(source: "Tunnel/JESUS_TUNNEL", data: "[XXXXXXXX] [wdn**666.JESUS_TUNNEL] 隧道启动成功", time: "2021/01/01 23:33:33", level: .info),
            LogModel(source: "Tunnel/JESUS_TUNNEL", data: "UDP 类型隧道启动成功", time: "", level: .none),
            LogModel(source: "Tunnel/JESUS_TUNNEL", data: "使用 [us-sj-cuvip.sakurafrp.com:2333] 来连接到你的隧道", time: "", level: .none),
            LogModel(source: "Tunnel/JESUS_TUNNEL", data: "或使用 IP 地址连接（不推荐）：[114.51.4.19:19810]", time: "", level: .none),
        ]
    }
}
#endif
