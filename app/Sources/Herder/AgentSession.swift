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
    var transcriptPath: String?
    
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
    
    /// Reads the current git branch from .git/HEAD
    var gitBranch: String? {
        let headPath = "\(cwd)/.git/HEAD"
        guard let content = try? String(contentsOfFile: headPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        // "ref: refs/heads/main" → "main"
        if content.hasPrefix("ref: refs/heads/") {
            return String(content.dropFirst("ref: refs/heads/".count))
        }
        // Detached HEAD — show short hash
        return String(content.prefix(8))
    }
    
    var elapsedString: String {
        let minutes = Int(Date().timeIntervalSince(startTime)) / 60
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }
}
