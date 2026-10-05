import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var manager: PowerManager? {
        didSet {
            dockIcons = manager.map { DockIconController(manager: $0) }
            configurationTimer?.invalidate()
            guard manager != nil else { return }
            configurationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.manager?.refresh(preservingSelection: true)
                }
            }
        }
    }

    private var dockIcons: DockIconController?
    private var configurationTimer: Timer?
    private var wakeObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        wakeObservation = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.manager?.refresh(preservingSelection: true) }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        manager?.refresh(preservingSelection: true)
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard let manager else { return nil }
        manager.refresh(preservingSelection: true)
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (index, mode) in LidMode.allCases.enumerated() {
            let item = NSMenuItem(title: mode.title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = manager.snapshot?.matchesTarget(mode) == true ? .on : .off
            item.isEnabled = manager.passwordlessEnabled && manager.snapshot != nil &&
                !manager.isApplying && !manager.isConfiguringAccess
            menu.addItem(item)
        }
        if !manager.passwordlessEnabled {
            menu.addItem(.separator())
            let hint = NSMenuItem(title: "请打开应用，启用免密切换", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        }
        return menu
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let manager, LidMode.allCases.indices.contains(sender.tag),
              manager.passwordlessEnabled, manager.snapshot != nil,
              !manager.isApplying, !manager.isConfiguringAccess else { return }
        let mode = LidMode.allCases[sender.tag]
        if mode == .keepRunning {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "合盖后电脑会继续运行"
            alert.informativeText = "此档位会阻止合盖和空闲自动休眠，电池供电时也生效。退出软件后设置仍会保留；放入背包前请切换到休眠或睡眠。"
            alert.addButton(withTitle: "确认开启")
            alert.addButton(withTitle: "取消")
            alert.buttons[1].keyEquivalent = "\u{1b}"
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        manager.selectedMode = mode
        manager.applySelected()
        if let error = manager.error {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "档位切换未确认"
            alert.informativeText = error
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }
}
