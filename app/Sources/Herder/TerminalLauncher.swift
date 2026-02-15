import AppKit
import Foundation

struct TerminalLauncher {
    
    static func open(session: AgentSession) {
        let terminalApp = session.terminalApp ?? detectDefaultTerminal()
        
        switch terminalApp {
        case "warp":
            activateWarpTab(session: session)
        case "iterm2":
            activateITermTab(session: session)
        case "terminal":
            activateTerminalTab(session: session)
        case "vscode", "cursor":
            activateApp(bundleId: terminalApp == "vscode" ? "com.microsoft.VSCode" : "com.todesktop.230313mzl4w4u92")
        default:
            activateWarpTab(session: session)
        }
    }
    
    // MARK: - Warp
    
    private static func activateWarpTab(session: AgentSession) {
        // Activate Warp first
        activateApp(bundleId: "dev.warp.Warp-Stable")
        
        // Use System Events to find and activate the tab matching the cwd
        // Warp tab titles typically contain the directory name
        let dirName = (session.cwd as NSString).lastPathComponent
        let shortCwd = session.shortCwd
        
        let script = """
        tell application "System Events"
            tell process "Warp"
                set frontmost to true
                delay 0.3
                
                -- Try to find the window/tab with matching title
                set found to false
                repeat with w in windows
                    set winTitle to name of w
                    if winTitle contains "\(dirName.escapedForAppleScript())" then
                        perform action "AXRaise" of w
                        set found to true
                        exit repeat
                    end if
                end repeat
                
                if not found then
                    -- Try menu bar: Window menu to find tab
                    try
                        click menu bar item "Window" of menu bar 1
                        delay 0.2
                        set menuItems to menu items of menu "Window" of menu bar item "Window" of menu bar 1
                        repeat with mi in menuItems
                            try
                                set itemName to name of mi
                                if itemName contains "\(dirName.escapedForAppleScript())" then
                                    click mi
                                    set found to true
                                    exit repeat
                                end if
                            end try
                        end repeat
                        if not found then
                            -- Close the menu if we didn't find anything
                            key code 53
                        end if
                    end try
                end if
            end tell
        end tell
        """
        
        runAppleScript(script)
    }
    
    // MARK: - iTerm2
    
    private static func activateITermTab(session: AgentSession) {
        let dirName = (session.cwd as NSString).lastPathComponent
        
        let script = """
        tell application "iTerm"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if name of s contains "\(dirName.escapedForAppleScript())" then
                            select t
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
        
        runAppleScript(script)
    }
    
    // MARK: - Terminal.app
    
    private static func activateTerminalTab(session: AgentSession) {
        let dirName = (session.cwd as NSString).lastPathComponent
        
        let script = """
        tell application "Terminal"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    if custom title of t contains "\(dirName.escapedForAppleScript())" or history of t contains "\(dirName.escapedForAppleScript())" then
                        set selected tab of w to t
                        set index of w to 1
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        
        runAppleScript(script)
    }
    
    // MARK: - Helpers
    
    private static func detectDefaultTerminal() -> String {
        let terminals = [
            ("dev.warp.Warp-Stable", "warp"),
            ("com.googlecode.iterm2", "iterm2"),
            ("com.apple.Terminal", "terminal")
        ]
        for (bundleId, name) in terminals {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty {
                return name
            }
        }
        return "terminal"
    }
    
    private static func activateApp(bundleId: String) {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.activate()
    }
    
    private static func runAppleScript(_ script: String) {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
}

extension AgentSession {
    var shortCwdForLauncher: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if cwd.hasPrefix(home) { return "~" + cwd.dropFirst(home.count) }
        return cwd
    }
}

extension String {
    func escapedForAppleScript() -> String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}
