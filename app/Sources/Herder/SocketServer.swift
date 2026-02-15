import Foundation

actor SocketServer {
    private let socketPath = "/tmp/herder.sock"
    private var socketFileDescriptor: Int32?
    private var isRunning = false
    private let store: AgentStore
    
    init(store: AgentStore) {
        self.store = store
    }
    
    func start() {
        guard !isRunning else { return }
        unlink(socketPath)
        
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { print("Error: Could not create socket"); return }
        
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            _ = socketPath.withCString { cString in strcpy(ptr, cString) }
        }
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bindResult == 0 else { print("Error: Could not bind socket"); close(fd); return }
        guard listen(fd, 5) == 0 else { print("Error: Could not listen"); close(fd); return }
        
        socketFileDescriptor = fd
        isRunning = true
        print("Socket server listening on \(socketPath)")
        Task { await acceptConnections() }
    }
    
    func stop() {
        isRunning = false
        if let fd = socketFileDescriptor { close(fd) }
        unlink(socketPath)
    }
    
    private func acceptConnections() async {
        guard let fd = socketFileDescriptor else { return }
        while isRunning {
            let clientFd = accept(fd, nil, nil)
            if clientFd < 0 { continue }
            Task { await handleClient(fd: clientFd) }
        }
    }
    
    private func handleClient(fd: Int32) async {
        defer { close(fd) }
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else { return }
        let data = Data(bytes: buffer, count: bytesRead)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else { return }
        await processEvent(event: event, data: json)
    }
    
    private func processEvent(event: String, data: [String: Any]) async {
        guard let sessionId = data["session_id"] as? String else { return }
        await MainActor.run {
            switch event {
            case "session_start":
                if let cwd = data["cwd"] as? String { store.addSession(id: sessionId, cwd: cwd) }
            case "session_end":
                store.removeSession(id: sessionId)
            case "agent_idle":
                store.updateSessionStatus(id: sessionId, status: .idle, lastMessage: data["last_message"] as? String)
            case "agent_active":
                store.updateSessionStatus(id: sessionId, status: .working)
            default: break
            }
        }
    }
}
