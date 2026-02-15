import Foundation

/// Representa una sesión de agente de Claude Code
struct AgentSession: Identifiable, Equatable {
    let id: String // session_id
    let cwd: String
    var status: Status
    var lastMessage: String?
    let startTime: Date
    var lastActivity: Date
    
    enum Status: Equatable {
        case working   // Agente está procesando
        case idle      // Agente esperando input del usuario
    }
    
    init(id: String, cwd: String, status: Status = .working) {
        self.id = id
        self.cwd = cwd
        self.status = status
        self.lastMessage = nil
        self.startTime = Date()
        self.lastActivity = Date()
    }
    
    /// Versión corta del directorio (sin home path)
    var shortCwd: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if cwd.hasPrefix(home) {
            return "~" + cwd.dropFirst(home.count)
        }
        return cwd
    }
    
    /// Tiempo corriendo
    var elapsed: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    /// String formateado del tiempo corriendo
    var elapsedString: String {
        let minutes = Int(elapsed) / 60
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}
