import Foundation

struct AgentSession: Identifiable, Equatable {
    let id: String
    let cwd: String
    var status: Status
    var lastMessage: String?
    let startTime: Date
    var lastActivity: Date
    var tty: String?
    var terminalPid: String?
    var terminalApp: String?  // "warp", "iterm2", "terminal", "vscode", "cursor"
    
    enum Status: Equatable {
        case working
        case idle
    }
    
    init(id: String, cwd: String, status: Status = .working, tty: String? = nil, terminalPid: String? = nil, terminalApp: String? = nil) {
        self.id = id
        self.cwd = cwd
        self.status = status
        self.startTime = Date()
        self.lastActivity = Date()
        self.tty = tty
        self.terminalPid = terminalPid
        self.terminalApp = terminalApp
    }
    
    var shortCwd: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if cwd.hasPrefix(home) {
            return "~" + cwd.dropFirst(home.count)
        }
        return cwd
    }
    
    var elapsedString: String {
        let minutes = Int(Date().timeIntervalSince(startTime)) / 60
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }
}
