import Foundation

/// Unix domain socket server using GCD for non-blocking I/O
class SocketServer {
    private let socketPath = "/tmp/herder.sock"
    private var socketSource: DispatchSourceRead?
    private var socketFd: Int32 = -1
    private let store: AgentStore
    private let queue = DispatchQueue(label: "com.qouter.herder.socket")
    
    init(store: AgentStore) {
        self.store = store
    }
    
    func start() {
        // Clean up old socket
        unlink(socketPath)
        
        // Create socket
        socketFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFd >= 0 else {
            print("Error: Could not create socket")
            return
        }
        
        // Make non-blocking
        let flags = fcntl(socketFd, F_GETFL)
        fcntl(socketFd, F_SETFL, flags | O_NONBLOCK)
        
        // Bind
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            _ = socketPath.withCString { strcpy(ptr, $0) }
        }
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            print("Error: Could not bind socket (errno: \(errno))")
            close(socketFd)
            return
        }
        
        guard listen(socketFd, 5) == 0 else {
            print("Error: Could not listen on socket")
            close(socketFd)
            return
        }
        
        // Use GCD dispatch source to handle incoming connections
        let source = DispatchSource.makeReadSource(fileDescriptor: socketFd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.socketFd, fd >= 0 {
                close(fd)
            }
        }
        source.resume()
        socketSource = source
        
        print("Socket server listening on \(socketPath)")
    }
    
    func stop() {
        socketSource?.cancel()
        socketSource = nil
        unlink(socketPath)
    }
    
    private func acceptConnection() {
        let clientFd = accept(socketFd, nil, nil)
        guard clientFd >= 0 else { return }
        
        // Read data from client
        queue.async { [weak self] in
            self?.handleClient(fd: clientFd)
        }
    }
    
    private func handleClient(fd: Int32) {
        defer { close(fd) }
        
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else { return }
        
        let data = Data(bytes: buffer, count: bytesRead)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String,
              let sessionId = json["session_id"] as? String else {
            print("Invalid JSON received")
            return
        }
        
        print("Received event: \(event) for session: \(sessionId)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch event {
            case "session_start":
                if let cwd = json["cwd"] as? String {
                    let tty = json["tty"] as? String
                    let terminalPid = json["terminal_pid"] as? String
                    let terminalApp = json["terminal_app"] as? String
                    self.store.addSession(id: sessionId, cwd: cwd, tty: tty, terminalPid: terminalPid, terminalApp: terminalApp)
                }
            case "session_end":
                self.store.removeSession(id: sessionId)
            case "agent_idle":
                self.store.updateSessionStatus(id: sessionId, status: .idle, lastMessage: json["last_message"] as? String)
            case "agent_active":
                self.store.updateSessionStatus(id: sessionId, status: .working)
            default:
                print("Unknown event: \(event)")
            }
        }
    }
}
