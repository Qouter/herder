import AppKit
import Foundation

struct TerminalLauncher {
    
    static func open(session: AgentSession) {
        // Try to activate the exact terminal window first
        if let pid = session.terminalPid, let pidInt = Int32(pid) {
            if let app = NSRunningApplication(processIdentifier: pidInt) {
                app.activate()
                return
            }
        }
        
        // Fall back to activating by terminal app type
        if let terminalApp = session.terminalApp {
            switch terminalApp {
            case "warp":
                activateApp(bundleId: "dev.warp.Warp-Stable")
            case "iterm2":
                activateApp(bundleId: "com.googlecode.iterm2")
            case "vscode":
                activateApp(bundleId: "com.microsoft.VSCode")
            case "cursor":
                activateApp(bundleId: "com.todesktop.230313mzl4w4u92")
            case "terminal":
                activateApp(bundleId: "com.apple.Terminal")
            default:
                openNewTerminal(directory: session.cwd)
            }
            return
        }
        
        // Last resort: open new terminal at directory
        openNewTerminal(directory: session.cwd)
    }
    
    private static func activateApp(bundleId: String) {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            app.activate()
        }
    }
    
    private static func openNewTerminal(directory: String) {
        // Try Warp first, then iTerm2, then Terminal.app
        let terminals = [
            ("dev.warp.Warp-Stable", "Warp"),
            ("com.googlecode.iterm2", "iTerm"),
            ("com.apple.Terminal", "Terminal")
        ]
        
        for (bundleId, name) in terminals {
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil {
                let script: String
                if name == "Warp" {
                    script = """
                    tell application "Warp"
                        activate
                    end tell
                    delay 0.5
                    tell application "System Events"
                        keystroke "t" using command down
                    end tell
                    """
                } else if name == "iTerm" {
                    script = """
                    tell application "iTerm"
                        activate
                        tell current window
                            create tab with default profile
                            tell current session
                                write text "cd '\(directory.escapedForAppleScript())'"
                            end tell
                        end tell
                    end tell
                    """
                } else {
                    script = """
                    tell application "Terminal"
                        activate
                        do script "cd '\(directory.escapedForAppleScript())'"
                    end tell
                    """
                }
                
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    scriptObject.executeAndReturnError(&error)
                }
                return
            }
        }
    }
}

extension String {
    func escapedForAppleScript() -> String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}
