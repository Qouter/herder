import SwiftUI

struct AgentListView: View {
    @ObservedObject var store: AgentStore
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Herder")
                    .font(.headline)
                Spacer()
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "gear").foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }.padding()
            
            Divider()
            
            if store.sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz").font(.system(size: 48)).foregroundColor(.secondary)
                    Text("No active agents").font(.subheadline).foregroundColor(.secondary)
                    Text("Start a Claude Code session to see it here").font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.sessions) { session in
                            AgentRowView(session: session)
                            if session.id != store.sessions.last?.id { Divider().padding(.leading, 16) }
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Text("\(store.totalCount) active · \(store.idleCount) waiting").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.plain).foregroundColor(.red)
            }.padding(.horizontal).padding(.vertical, 8)
        }.frame(width: 350, height: 400)
    }
}
