import AppKit
import Foundation

/// Utilidad para abrir Terminal/iTerm2 en un directorio específico
struct TerminalLauncher {
    
    /// Abre el terminal preferido en el directorio especificado
    static func open(directory: String) {
        // Intentar iTerm2 primero
        if isiTerm2Installed() {
            openITerm2(directory: directory)
        } else {
            // Fallback a Terminal.app
            openTerminal(directory: directory)
        }
    }
    
    // MARK: - Terminal.app
    
    private static func openTerminal(directory: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(directory.escapedForAppleScript())'"
        end tell
        """
        
        runAppleScript(script)
    }
    
    // MARK: - iTerm2
    
    private static func isiTerm2Installed() -> Bool {
        let workspace = NSWorkspace.shared
        let url = workspace.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2")
        return url != nil
    }
    
    private static func openITerm2(directory: String) {
        let script = """
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
        
        runAppleScript(script)
    }
    
    // MARK: - AppleScript Runner
    
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

// MARK: - String Extension

extension String {
    /// Escapa caracteres especiales para AppleScript
    func escapedForAppleScript() -> String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}
