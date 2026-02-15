import SwiftUI

/// Vista de una fila individual de agente
struct AgentRowView: View {
    let session: AgentSession
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 20))
                .frame(width: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // CWD
                Text(session.shortCwd)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                
                // Status text or last message
                if let lastMessage = session.lastMessage, !lastMessage.isEmpty {
                    Text(lastMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Elapsed time
                Text(session.elapsedString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Open button
            Button(action: {
                TerminalLauncher.open(directory: session.cwd)
            }) {
                Text("Open")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var statusIcon: String {
        switch session.status {
        case .working:
            return "circle.fill"
        case .idle:
            return "pause.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch session.status {
        case .working:
            return .green
        case .idle:
            return .orange
        }
    }
    
    private var statusText: String {
        switch session.status {
        case .working:
            return "Working..."
        case .idle:
            return "Waiting for you"
        }
    }
}
