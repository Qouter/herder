import Foundation
import Combine

/// Global store for agent sessions
class AgentStore: ObservableObject, @unchecked Sendable {
    @Published var sessions: [AgentSession] = []
    
    private var timeoutTimer: Timer?
    private let sessionTimeout: TimeInterval = 5 * 60
    
    init() {
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.cleanupStaleSessions()
            }
        }
    }
    
    deinit {
        timeoutTimer?.invalidate()
    }
    
    var totalCount: Int { sessions.count }
    var idleCount: Int { sessions.filter { $0.status == .idle }.count }
    var workingCount: Int { sessions.filter { $0.status == .working }.count }
    
    func addSession(id: String, cwd: String) {
        guard !sessions.contains(where: { $0.id == id }) else { return }
        sessions.append(AgentSession(id: id, cwd: cwd, status: .working))
    }
    
    func removeSession(id: String) {
        sessions.removeAll { $0.id == id }
    }
    
    func updateSessionStatus(id: String, status: AgentSession.Status, lastMessage: String? = nil) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].status = status
            sessions[index].lastActivity = Date()
            if let message = lastMessage {
                sessions[index].lastMessage = message
            }
        }
    }
    
    private func cleanupStaleSessions() {
        let now = Date()
        sessions.removeAll { now.timeIntervalSince($0.lastActivity) > sessionTimeout }
    }
}
