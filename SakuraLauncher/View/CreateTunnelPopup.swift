import SwiftUI
import WebKit

struct SwiftUIWebView: NSViewRepresentable {
    public typealias NSViewType = WKWebView

    let launcherHandler: SakuraLauncherHandler
    let createTunnelHandler: CreateTunnelHandler

    public func makeNSView(context _: NSViewRepresentableContext<SwiftUIWebView>) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        configuration.userContentController.addScriptMessageHandler(launcherHandler, contentWorld: .page, name: "SakuraLauncher")
        configuration.userContentController.addScriptMessageHandler(createTunnelHandler, contentWorld: .page, name: "CreateTunnel")

#if DEBUG
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.load(URLRequest(url: URL(string: "https://www.natfrp.com/_launcher/create-tunnel")!))
        return webView
    }

    public func updateNSView(_: WKWebView, context _: NSViewRepresentableContext<SwiftUIWebView>) {}
}

struct CreateTunnelPopup: View {
    @EnvironmentObject var model: LauncherModel

    @Environment(\.dismiss) private var dismiss

    @Binding var editTunnel: String?

    var body: some View {
        SwiftUIWebView(
            launcherHandler: SakuraLauncherHandler(model),
            createTunnelHandler: CreateTunnelHandler(
                model: model,
                editTunnel: editTunnel,
                closeAction: { dismiss() }
            )
        )
    }
}

#if DEBUG
struct CreateTunnelPopup_Previews: PreviewProvider {
    static var previews: some View {
        CreateTunnelPopup(editTunnel: .constant(nil))
            .environmentObject(LauncherModel_Preview() as LauncherModel)
    }
}
#endif
