import AppKit

@main
struct DockMenuChecks {
    @MainActor
    static func main() {
        let sleep = PowerSnapshot(sleepDisabled: false, batteryHibernateMode: 3,
                                  acHibernateMode: 3, powerSource: "电池")
        var enabled = false
        var applied: LidMode?
        let manager = PowerManager(
            readSettings: { sleep }, applySettings: { applied = $0 }, requestSleep: {},
            readPasswordlessStatus: { enabled }, configurePasswordless: { enabled = $0 }
        )
        let delegate = AppDelegate()
        delegate.manager = manager
        let locked = delegate.applicationDockMenu(NSApplication.shared)!
        precondition(locked.items.prefix(3).allSatisfy { !$0.isEnabled })
        enabled = true
        let menu = delegate.applicationDockMenu(NSApplication.shared)!
        precondition(Array(menu.items.prefix(3).map(\.title)) == LidMode.allCases.map(\.title))
        precondition(menu.items.prefix(3).allSatisfy(\.isEnabled))
        precondition(menu.items[1].state == .on && menu.items[0].state == .off)
        precondition(applied == nil, "Opening the Dock menu must only read current settings")
        menu.performActionForItem(at: 1)
        precondition(applied == .sleep, "The Dock menu must apply the chosen mode directly")
        print("dock menu checks passed")
    }
}
