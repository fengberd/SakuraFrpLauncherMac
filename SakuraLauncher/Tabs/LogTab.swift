import SwiftUI

struct LogTab: View {
    let timeColor = Color(red: 0.31, green: 0.55, blue: 0.86),
        sourceColor = Color(red: 0.96, green: 0.87, blue: 0.70),
        dataColor = Color(red: 0.75, green: 0.75, blue: 0.75)

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var model: LauncherModel

    @State var filter = ""

    @Binding var lastScrollOffset: UUID?
    @State private var current: [UUID] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("日志")
                    .font(.title)
                    .padding(.leading, 24)
                Button(action: {
                    model.logs = []
                    model.logFilters = [:]

                    filter = ""

                    model.rpcWithAlert { [self] in
                        _ = try await model.RPC?.clearLog(model.rpcEmpty)
                    }
                }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 16))

                Spacer()

                Menu(filter == "" ? "过滤..." : filter) {
                    Button("显示所有日志", action: {
                        filter = ""
                    })
                    ForEach(Array(model.logFilters.keys), id: \.self) { f in
                        Button(f, action: {
                            filter = f
                        })
                    }
                }
                .frame(width: 200)
                .padding(.trailing)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filter == "" ? model.logs : model.logs.filter { $0.source == filter }, id: \.id) { l in
                            logLine(l)
                                .onAppear {
                                    current.append(l.id)

                                    if let last = model.logs.last(where: { l in current.contains(l.id) }) {
                                        if last.id != model.logs.last?.id {
                                            lastScrollOffset = last.id
                                        } else {
                                            lastScrollOffset = nil
                                        }
                                    } else {
                                        lastScrollOffset = nil
                                    }
                                }
                                .onDisappear { current.removeAll { $0 == l.id } }
                        }
                    }
                    .id("logs")
                    .font(.custom("monaco", size: 12))
                    .padding(8)
                }
                .onAppear {
                    if let offset = lastScrollOffset {
                        proxy.scrollTo(offset, anchor: .bottom)
                    } else {
                        proxy.scrollTo("logs", anchor: .bottom)
                    }
                }
                .onChange(of: model.logs.count) { _ in
                    if lastScrollOffset == nil {
                        proxy.scrollTo("logs", anchor: .bottom)
                    }
                }
                .onChange(of: filter) { _ in
                    proxy.scrollTo("logs", anchor: .bottom)
                }
            }
            .background(Color.black.opacity(colorScheme == .dark ? 0.2 : 0.8))
            .border(colorScheme == .dark ? Color.secondary.opacity(0.8) : Color.gray, width: 2)
            .padding()
        }
    }

    private func logLine(_ l: LogModel) -> some View {
        Text("\(l.time) ").foregroundColor(timeColor) +
            Text("\(l.level.rawValue) ").foregroundColor(l.levelColor()) +
            Text("\(l.source) ").foregroundColor(sourceColor) +
            Text(l.data).foregroundColor(dataColor)
    }
}

#if DEBUG
struct LogTab_Previews: PreviewProvider {
    static var previews: some View {
        LogTab(lastScrollOffset: .constant(nil))
            .previewLayout(.fixed(width: 602, height: 500))
            .environmentObject(LauncherModel_Preview() as LauncherModel)
    }
}
#endif
