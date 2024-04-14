import SwiftUI

struct TunnelTab: View {
    @Environment(\.openWindow) var openWindow

    @EnvironmentObject var model: LauncherModel

    @State var reloading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("隧道")
                    .font(.title)
                    .padding(.leading, 24)

                Button(action: {
                    openWindow(id: "create-tunnel")
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 16))
                .padding(.leading, 8)

                Button(action: {
                    reloading = true
                    model.rpcWithAlert({
                        _ = try await model.RPC?.reloadTunnels(model.rpcEmpty)
                    }) { reloading = false }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 16))
                .padding(.leading, 8)
                .disabled(reloading)
            }
            if model.tunnels.count == 0 {
                Text("还没有隧道哦")
                    .font(.title2)
                    .foregroundColor(.primary.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: .init(.adaptive(minimum: 260), spacing: 20), count: Int(geometry.size.width / 260)), alignment: .leading, spacing: 20) {
                            ForEach(model.tunnels, id: \.id) { t in
                                TunnelItemView(tunnel: t).contextMenu {
                                    Button("编辑隧道") {
                                        openWindow(id: "create-tunnel", value: try! t.proto.jsonString())
                                    }
                                    Button("删除隧道") {
                                        let alert = NSAlert()
                                        alert.messageText = "操作确认"
                                        alert.informativeText = "是否确认删除隧道 #\(String(t.id)) \(t.name)?"
                                        alert.alertStyle = .warning
                                        alert.addButton(withTitle: "确认删除")
                                        alert.addButton(withTitle: "取消")
                                        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
                                            model.rpcWithAlert {
                                                _ = try await model.RPC?.updateTunnel(.with {
                                                    $0.action = .delete
                                                    $0.tunnel = .with {
                                                        $0.id = t.id
                                                    }
                                                })
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top)
                        .padding(.bottom, 24)
                        .padding(.leading, 24)
                        .padding(.trailing, 24)
                    }
                }
            }
        }
    }
}

#if DEBUG
struct TunnelTab_Previews: PreviewProvider {
    static var previews: some View {
        TunnelTab()
            .environmentObject(LauncherModel_Preview() as LauncherModel)
    }
}
#endif
