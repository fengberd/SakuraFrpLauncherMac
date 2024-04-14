import WebKit

class SakuraLauncherHandler: NSObject, WKScriptMessageHandlerWithReply {
    let model: LauncherModel

    init(_ model: LauncherModel) {
        self.model = model
    }

    @MainActor func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        if message.name != "SakuraLauncher" {
            replyHandler(nil, "Invalid handler")
            return
        }

        let call = message.body as? [String]
        if call == nil || call!.count < 1 {
            replyHandler(nil, "Invalid data")
            return
        }

        do {
            switch call![0] {
            case "GetLauncherVersion":
                replyHandler(Bundle.main.infoDictionary!["CFBundleShortVersionString"], nil)
            case "GetServiceVersion":
                replyHandler(model.update.serviceVersion, nil)
            case "GetFrpcVersion":
                replyHandler(model.update.frpcVersion, nil)
            case "GetUser":
                try replyHandler(model.user.jsonString(), nil)
            case "GetNodes":
                var nodeList = NodeList()
                for node in model.nodes {
                    nodeList.nodes[node.key] = node.value.proto
                }
                try replyHandler(nodeList.jsonString(), nil)
            case "GetNotifications":
                try replyHandler(model.notifications.jsonString(), nil)
            case "GetAdvancedMode":
                replyHandler(model.advancedMode, nil)
            default:
                replyHandler(nil, "Method not found")
            }
        } catch {
            replyHandler(nil, error.localizedDescription)
        }
    }
}

class CreateTunnelHandler: NSObject, WKScriptMessageHandlerWithReply {
    let model: LauncherModel
    let editTunnel: String?
    let closeAction: () -> Void

    init(model: LauncherModel, editTunnel: String? = nil, closeAction: @escaping () -> Void) {
        self.model = model
        self.editTunnel = editTunnel
        self.closeAction = closeAction
    }

    @MainActor func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        if message.name != "CreateTunnel" {
            replyHandler(nil, "Invalid handler")
            return
        }

        let call = message.body as? [String]
        if call == nil || call!.count < 1 {
            replyHandler(nil, "Invalid data")
            return
        }

        do {
            switch call![0] {
            case "CloseWindow":
                closeAction()
                replyHandler(nil, nil)
            case "GetEditTunnel":
                replyHandler(editTunnel ?? "", nil)
            case "EditTunnel":
                let tunnel = try Tunnel(jsonString: call![1])
                model.rpcWithAlert({
                    _ = try await self.model.RPC?.updateTunnel(.with {
                        $0.action = .edit
                        $0.tunnel = tunnel
                    })
                }) {
                    self.closeAction()
                    replyHandler(nil, nil)
                }
            case "CreateTunnel":
                let tunnel = try Tunnel(jsonString: call![1])
                model.rpcWithAlert({
                    _ = try await self.model.RPC?.updateTunnel(.with {
                        $0.action = .add
                        $0.tunnel = tunnel
                    })
                }) {
                    self.closeAction()
                    replyHandler(nil, nil)
                }
            case "AuthTunnel":
                model.rpcWithAlert({
                    _ = try await self.model.RPC?.authTunnel(TunnelAuthRequest(jsonString: call![1]))
                }) {
                    replyHandler(nil, nil)
                }
            case "GetListening":
                replyHandler("0[]", nil)
            case "ReloadListening":
                replyHandler(nil, nil)
            default:
                replyHandler(nil, "Method not found")
            }
        } catch {
            replyHandler(nil, error.localizedDescription)
        }
    }
}
