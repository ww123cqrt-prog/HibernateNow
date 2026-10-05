import AppKit

@main
struct DockIconChecks {
    @MainActor
    static func main() {
        func snapshot(_ mode: LidMode) -> PowerSnapshot {
            PowerSnapshot(sleepDisabled: mode == .keepRunning,
                          batteryHibernateMode: mode == .hibernate ? 25 : 3,
                          acHibernateMode: mode == .hibernate ? 25 : 3, powerSource: "电池")
        }
        var current: PowerSnapshot? = snapshot(.sleep)
        let manager = PowerManager(
            readSettings: {
                guard let current else { throw PowerError.unreadableSettings }
                return current
            },
            applySettings: { current = snapshot($0) }, requestSleep: {},
            readPasswordlessStatus: { false }
        )
        var displayed: [LidMode?] = []
        let controller = DockIconController(manager: manager, displayIcon: { displayed.append($0) })
        defer { withExtendedLifetime(controller) {} }
        precondition(displayed == [.sleep], "Start from the configuration actually read from the system")
        manager.selectedMode = .hibernate
        precondition(displayed == [.sleep], "A pending selection must not change the Dock status")
        manager.applySelected()
        precondition(displayed.last! == .hibernate)
        manager.refresh(preservingSelection: true)
        precondition(displayed.count == 2, "Repeated identical reads must not redraw the Dock")
        current = snapshot(.keepRunning)
        manager.refresh(preservingSelection: true)
        precondition(displayed.last! == .keepRunning, "External configuration changes must update the icon")
        current = PowerSnapshot(sleepDisabled: true, batteryHibernateMode: 25,
                                acHibernateMode: 25, powerSource: "电池")
        manager.refresh()
        precondition(displayed.last! == nil, "A mixed triple must not be shown as a confirmed running mode")
        current = snapshot(.sleep)
        manager.refresh()
        precondition(displayed.last! == .sleep)
        current = nil
        manager.refresh()
        precondition(displayed.last! == nil, "A read failure must invalidate the old icon")
        print("dock icon state checks passed")
    }
}
