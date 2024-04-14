import SwiftUI

struct AboutTab: View {
    @EnvironmentObject var model: LauncherModel

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 0) {
                Text("SakuraFrp Launcher for macOS")
                    .font(.title)

                Text("版本 \(Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String) / \(model.update.serviceVersion) / \(model.update.frpcVersion)")
                    .font(.title2)
                    .padding(.top, 14)

                Text("版权所有 © 2021-2024 iDea Leaper")
                    .font(.title3)
                    .padding(.top, 14)
                Link("https://github.com/natfrp/launcher-macos", destination: URL(string: "https://github.com/natfrp/launcher-macos")!)
                    .padding(.top, 4)
            }
            .padding(.leading, 24)

            ScrollView {
                VStack(alignment: .leading) {
                    Text(String(data: NSDataAsset(name: "LICENSE")!.data, encoding: .utf8)!)
                        .lineLimit(nil)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
            }
            .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.2))
            .border(Color.secondary.opacity(0.8), width: 2)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .padding(.leading, 24)
            .padding(.trailing, 24)
        }
    }
}

#if DEBUG
struct AboutTab_Previews: PreviewProvider {
    static var previews: some View {
        AboutTab()
    }
}
#endif
