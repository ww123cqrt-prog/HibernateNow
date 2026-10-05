import AppKit
import Combine

@MainActor
final class DockIconController {
    private var observation: AnyCancellable?

    init(
        manager: PowerManager,
        displayIcon: ((LidMode?) -> Void)? = nil
    ) {
        let displayIcon = displayIcon ?? { mode in Self.updateApplicationIcon(mode) }
        observation = manager.$snapshot
            .map { snapshot in
                LidMode.allCases.first { snapshot?.matchesTarget($0) == true }
            }
            .removeDuplicates()
            .sink(receiveValue: displayIcon)
    }

    static func icon(for mode: LidMode, bundle: Bundle = .main) -> NSImage? {
        guard let url = bundle.url(forResource: mode.rawValue, withExtension: "icns", subdirectory: "DockIcons") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static func updateApplicationIcon(_ mode: LidMode?) {
        guard let mode, let image = icon(for: mode) else {
            // The neutral app artwork must not be mistaken for a confirmed state.
            NSApplication.shared.applicationIconImage = nil
            NSApplication.shared.dockTile.badgeLabel = "?"
            return
        }
        NSApplication.shared.applicationIconImage = image
        NSApplication.shared.dockTile.badgeLabel = nil
    }
}
