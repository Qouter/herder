import AppKit
import SwiftUI
import Combine

/// Menu bar icon and popover controller
class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let store: AgentStore
    private var cancellables = Set<AnyCancellable>()
    
    init(store: AgentStore) {
        self.store = store
        super.init()
        setupStatusItem()
        setupPopover()
        observeStoreChanges()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateTitle()
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 350, height: 400)
        popover?.behavior = .transient
        
        let contentView = AgentListView(store: store) { [weak self] in
            self?.closePopover()
        }
        
        popover?.contentViewController = NSHostingController(rootView: contentView)
    }
    
    private func observeStoreChanges() {
        store.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateTitle()
            }
            .store(in: &cancellables)
    }
    
    private func updateTitle() {
        let total = store.totalCount
        let idle = store.idleCount
        
        if total == 0 {
            statusItem?.button?.title = "🤖"
        } else if idle > 0 {
            statusItem?.button?.title = "🤖 \(total) | ⏳ \(idle)"
        } else {
            statusItem?.button?.title = "🤖 \(total)"
        }
    }
    
    @objc private func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }
    
    private func showPopover() {
        if let button = statusItem?.button, let popover = popover {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    private func closePopover() {
        popover?.performClose(nil)
    }
}
