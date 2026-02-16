import Foundation

/// Polls Claude Code transcript files to detect when an agent is waiting for user input.
/// This catches cases that hooks miss, like plan review prompts.
class TranscriptMonitor {
    private let store: AgentStore
    private var timer: Timer?
    private let pollInterval: TimeInterval = 5
    
    /// Tracks the last known file size per session to detect new content
    private var lastFileSize: [String: UInt64] = [:]
    /// Tracks how long a session has had no new transcript activity
    private var staleSeconds: [String: TimeInterval] = [:]
    
    init(store: AgentStore) {
        self.store = store
    }
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func poll() {
        let sessions = store.sessions
        
        for session in sessions {
            guard session.status == .working else {
                // Reset tracking for non-working sessions
                staleSeconds.removeValue(forKey: session.id)
                lastFileSize.removeValue(forKey: session.id)
                continue
            }
            
            // Try to find transcript if we don't have it
            let transcriptPath = session.transcriptPath ?? findTranscript(sessionId: session.id)
            
            guard let path = transcriptPath else { continue }
            
            // Store the transcript path if we found it
            if session.transcriptPath == nil {
                DispatchQueue.main.async {
                    self.store.setTranscriptPath(id: session.id, path: path)
                }
            }
            
            // Check file size for changes
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let fileSize = attrs[.size] as? UInt64 else { continue }
            
            let previousSize = lastFileSize[session.id] ?? 0
            
            if fileSize != previousSize {
                // File changed — reset stale counter, check content
                lastFileSize[session.id] = fileSize
                staleSeconds[session.id] = 0
                
                // Read last few lines to check for waiting patterns
                if let lastContent = readLastLines(path: path, count: 5) {
                    if isWaitingForInput(content: lastContent) {
                        DispatchQueue.main.async {
                            let message = self.extractLastMessage(from: lastContent)
                            self.store.updateSessionStatus(id: session.id, status: .idle, lastMessage: message)
                        }
                    }
                }
            } else {
                // File unchanged — accumulate stale time
                let stale = (staleSeconds[session.id] ?? 0) + pollInterval
                staleSeconds[session.id] = stale
                
                // If transcript hasn't changed in 15s while "working", check last entry
                if stale >= 15 {
                    if let lastContent = readLastLines(path: path, count: 5) {
                        // Either matches a known pattern, or transcript is stale with last message from assistant
                        if isWaitingForInput(content: lastContent) || (stale >= 20 && lastEntryIsAssistant(content: lastContent)) {
                            DispatchQueue.main.async {
                                let message = self.extractLastMessage(from: lastContent)
                                self.store.updateSessionStatus(id: session.id, status: .idle, lastMessage: message)
                            }
                        }
                    }
                    // Reset so we don't spam
                    staleSeconds[session.id] = 0
                }
            }
        }
    }
    
    /// Try to find the transcript file for a session by searching ~/.claude
    private func findTranscript(sessionId: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let claudeDir = "\(home)/.claude/projects"
        
        guard FileManager.default.fileExists(atPath: claudeDir) else { return nil }
        
        // Search for session_id.jsonl in the projects directory tree
        let filename = "\(sessionId).jsonl"
        if let found = findFile(named: filename, in: claudeDir, maxDepth: 4) {
            return found
        }
        return nil
    }
    
    private func findFile(named filename: String, in directory: String, maxDepth: Int) -> String? {
        guard maxDepth > 0 else { return nil }
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return nil }
        
        for entry in entries {
            let fullPath = "\(directory)/\(entry)"
            if entry == filename { return fullPath }
            
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                if let found = findFile(named: filename, in: fullPath, maxDepth: maxDepth - 1) {
                    return found
                }
            }
        }
        return nil
    }
    
    /// Read the last N lines of a file efficiently
    private func readLastLines(path: String, count: Int) -> [String]? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { handle.closeFile() }
        
        let fileSize = handle.seekToEndOfFile()
        let readSize = min(fileSize, 8192)  // Read last 8KB
        handle.seek(toFileOffset: fileSize - readSize)
        let data = handle.readData(ofLength: Int(readSize))
        
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        return Array(lines.suffix(count))
    }
    
    /// Check if the last transcript content indicates Claude is waiting for user input
    private func isWaitingForInput(content: [String]) -> Bool {
        // Check the last assistant message for common waiting patterns
        for line in content.reversed() {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let role = message["role"] as? String else { continue }
            
            if role == "assistant" {
                guard let contentArr = message["content"] as? [[String: Any]] else { return false }
                for block in contentArr {
                    if let text = block["text"] as? String {
                        return matchesWaitingPattern(text)
                    }
                }
                return false
            }
            
            // If the last entry is a tool_use or tool_result, agent is still working
            if role == "tool" || role == "function" { return false }
        }
        return false
    }
    
    /// Check if the last transcript entry is from the assistant (not a tool call)
    private func lastEntryIsAssistant(content: [String]) -> Bool {
        for line in content.reversed() {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let role = message["role"] as? String else { continue }
            
            if role == "assistant" {
                // Make sure it's a text block, not a tool_use
                if let contentArr = message["content"] as? [[String: Any]] {
                    return contentArr.contains { $0["type"] as? String == "text" }
                }
                return false
            }
            return false
        }
        return false
    }
    
    /// Detect patterns that indicate Claude is asking the user something
    private func matchesWaitingPattern(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let patterns = [
            // English
            "would you like to proceed",
            "would you like me to",
            "would you like to",
            "shall i ",
            "do you want me to",
            "do you want to",
            "should i ",
            "let me know",
            "what do you think",
            "does this look",
            "ready to execute",
            "please confirm",
            "approve",
            "which option",
            "which approach",
            "which one",
            "what would you prefer",
            "how would you like",
            "choose from",
            "select one",
            "pick one",
            // Spanish
            "¿quieres que",
            "¿te parece",
            "¿procedemos",
            "¿continúo",
            "¿sigo",
            "¿cuál de",
            "¿qué opción",
            "¿qué prefieres",
            "¿cómo prefieres",
            "te gustaría",
            "quieres que implemente",
            "qué enfoque",
        ]
        return patterns.contains { lowered.contains($0) }
    }
    
    /// Extract a short message from the last assistant content
    private func extractLastMessage(from content: [String]) -> String? {
        for line in content.reversed() {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let role = message["role"] as? String,
                  role == "assistant",
                  let contentArr = message["content"] as? [[String: Any]] else { continue }
            
            for block in contentArr {
                if let text = block["text"] as? String {
                    let clean = text.replacingOccurrences(of: "\n", with: " ")
                    return String(clean.prefix(100))
                }
            }
        }
        return nil
    }
}
