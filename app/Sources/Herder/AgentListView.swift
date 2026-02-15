import SwiftUI

struct AgentListView: View {
    @ObservedObject var store: AgentStore
    let onClose: () -> Void
    
    private var version: String {
        let versionFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".herder/VERSION")
        return (try? String(contentsOf: versionFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) ?? "dev"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Herder 🐑")
                    .font(.headline)
                Spacer()
                Text(version)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }.padding()
            
            Divider()
            
            if store.sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz").font(.system(size: 48)).foregroundColor(.secondary)
                    Text("No active agents").font(.subheadline).foregroundColor(.secondary)
                    Text("Start a new Claude Code session to see it here").font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Text("(Sessions started before Herder won't appear)").font(.caption2).foregroundColor(.secondary.opacity(0.7))
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
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }.padding(.horizontal).padding(.vertical, 8)
        }.frame(width: 350, height: 400)
    }
}
