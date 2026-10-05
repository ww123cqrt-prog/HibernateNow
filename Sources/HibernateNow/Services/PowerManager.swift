import Foundation

@MainActor
final class PowerManager: ObservableObject {
    @Published private(set) var snapshot: PowerSnapshot?
    @Published private(set) var isApplying = false
    @Published private(set) var passwordlessEnabled = false
    @Published private(set) var isConfiguringAccess = false
    @Published var selectedMode: LidMode = .sleep {
        didSet { hasPendingSelection = snapshot?.matchesTarget(selectedMode) != true }
    }
    @Published var notice: String?
    @Published var error: String?

    private let readSettings: () throws -> PowerSnapshot
    private let applySettings: (LidMode) throws -> Void
    private let requestSleep: () throws -> Void
    private let readPasswordlessStatus: () -> Bool
    private let configurePasswordless: (Bool) throws -> Void
    // User intent must survive an unreadable snapshot without keeping stale displayed settings.
    private var hasPendingSelection = false

    init(
        readSettings: @escaping () throws -> PowerSnapshot = { try PowerSettingsClient().read() },
        applySettings: @escaping (LidMode) throws -> Void = { try PrivilegedPowerControl().apply($0) },
        requestSleep: @escaping () throws -> Void = { try PrivilegedPowerControl().sleepNow() },
        readPasswordlessStatus: @escaping () -> Bool = { PasswordlessPowerAccess().isEnabled },
        configurePasswordless: @escaping (Bool) throws -> Void = { try PasswordlessPowerAccess().configure(enabled: $0) }
    ) {
        self.readSettings = readSettings
        self.applySettings = applySettings
        self.requestSleep = requestSleep
        self.readPasswordlessStatus = readPasswordlessStatus
        self.configurePasswordless = configurePasswordless
        refresh()
    }

    func refresh(preservingSelection: Bool = false) {
        guard !isApplying && !isConfiguringAccess else { return }
        notice = nil
        passwordlessEnabled = readPasswordlessStatus()
        let keepPendingChoice = preservingSelection && hasPendingSelection
        do {
            let latest = try readSettings()
            snapshot = latest
            if !keepPendingChoice {
                selectedMode = latest.lidMode ?? .sleep
                hasPendingSelection = false
            } else {
                hasPendingSelection = !latest.matchesTarget(selectedMode)
            }
            error = nil
        } catch {
            snapshot = nil
            self.error = error.localizedDescription
        }
    }

    func applySelected() {
        guard !isApplying && !isConfiguringAccess else { return }
        let target = selectedMode
        isApplying = true
        defer { isApplying = false }

        do {
            try applySettings(target)
            let latest = try readSettings()
            snapshot = latest
            guard latest.matchesTarget(target) else { throw PowerError.verificationFailed }
            hasPendingSelection = false
            notice = "已应用“\(target.title)”设置。"
            error = nil
        } catch {
            notice = nil
            self.error = error.localizedDescription
            // A partial command may have changed a setting. Never retain a stale snapshot.
            snapshot = try? readSettings()
            if let snapshot { hasPendingSelection = !snapshot.matchesTarget(selectedMode) }
        }
    }

    func sleepNow() {
        guard !isApplying && !isConfiguringAccess, snapshot?.sleepDisabled == false else { return }
        do {
            try requestSleep()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setPasswordlessEnabled(_ enabled: Bool) {
        guard !isApplying && !isConfiguringAccess else { return }
        isConfiguringAccess = true
        defer { isConfiguringAccess = false }
        notice = nil
        error = nil

        do {
            try configurePasswordless(enabled)
            passwordlessEnabled = readPasswordlessStatus()
            guard passwordlessEnabled == enabled else {
                throw PowerError.accessConfigurationFailed("系统未确认所请求的免密权限，请刷新后重试")
            }
            notice = enabled ? "免密切换已启用。可在 Dock 图标上右键切换档位。" : "免密切换已关闭，当前电源档位保持原样。"
        } catch {
            passwordlessEnabled = readPasswordlessStatus()
            self.error = error.localizedDescription
        }
    }
}
