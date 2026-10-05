import Foundation

@main
struct PowerManagerChecks {
    @MainActor
    static func main() {
        let hibernate = PowerSnapshot(
            sleepDisabled: false,
            batteryHibernateMode: 25,
            acHibernateMode: 25,
            powerSource: "电池"
        )
        let sleep = PowerSnapshot(
            sleepDisabled: false,
            batteryHibernateMode: 3,
            acHibernateMode: 3,
            powerSource: "电池"
        )
        let inconsistentKeepRunning = PowerSnapshot(
            sleepDisabled: true,
            batteryHibernateMode: 25,
            acHibernateMode: 25,
            powerSource: "电池"
        )

        var reads = 0
        let failedReadback = PowerManager(
            readSettings: {
                reads += 1
                if reads == 1 { return hibernate }
                throw PowerError.unreadableSettings
            },
            applySettings: { _ in },
            requestSleep: {}, readPasswordlessStatus: { false }
        )
        failedReadback.selectedMode = .keepRunning
        failedReadback.applySelected()
        precondition(failedReadback.snapshot == nil, "A failed readback must invalidate the old state")
        precondition(failedReadback.error?.contains("未作任何更改") == false)

        var current = hibernate
        let refreshed = PowerManager(
            readSettings: { current },
            applySettings: { _ in },
            requestSleep: {}, readPasswordlessStatus: { false }
        )
        refreshed.selectedMode = .hibernate
        refreshed.applySelected()
        precondition(refreshed.notice != nil)
        current = sleep
        refreshed.refresh()
        precondition(refreshed.notice == nil, "Refresh must remove an obsolete success message")

        var readback = hibernate
        let strictVerification = PowerManager(
            readSettings: { readback },
            applySettings: { _ in readback = inconsistentKeepRunning },
            requestSleep: {}, readPasswordlessStatus: { false }
        )
        strictVerification.selectedMode = .keepRunning
        strictVerification.applySelected()
        precondition(strictVerification.notice == nil, "Mixed settings must not pass verification")
        precondition(strictVerification.error != nil)

        var afterPartialFailure = hibernate
        let partialWrite = PowerManager(
            readSettings: { afterPartialFailure },
            applySettings: { _ in
                afterPartialFailure = sleep
                throw PowerError.authorizationFailed("第二条命令失败")
            },
            requestSleep: {}, readPasswordlessStatus: { false }
        )
        partialWrite.selectedMode = .sleep
        partialWrite.applySelected()
        precondition(partialWrite.snapshot == sleep, "A partial write must show the actual readback")
        precondition(partialWrite.error != nil)
        precondition(partialWrite.notice == nil)

        var currentOnReturn = hibernate
        let pendingChoice = PowerManager(
            readSettings: { currentOnReturn },
            applySettings: { _ in },
            requestSleep: {}, readPasswordlessStatus: { false }
        )
        pendingChoice.selectedMode = .keepRunning
        currentOnReturn = sleep
        pendingChoice.refresh(preservingSelection: true)
        precondition(pendingChoice.snapshot == sleep, "Return must read the latest configuration")
        precondition(pendingChoice.selectedMode == .keepRunning, "Return must preserve a pending choice")

        var currentWithoutPendingChoice = hibernate
        let noPendingChoice = PowerManager(
            readSettings: { currentWithoutPendingChoice },
            applySettings: { _ in },
            requestSleep: {}, readPasswordlessStatus: { false }
        )
        currentWithoutPendingChoice = sleep
        noPendingChoice.refresh(preservingSelection: true)
        precondition(noPendingChoice.selectedMode == .sleep, "Return must sync when there is no pending choice")

        var enabled = false
        let accessManager = PowerManager(
            readSettings: { sleep }, applySettings: { _ in }, requestSleep: {},
            readPasswordlessStatus: { enabled },
            configurePasswordless: { enabled = $0 }
        )
        accessManager.setPasswordlessEnabled(true)
        precondition(accessManager.passwordlessEnabled && accessManager.error == nil)
        precondition(accessManager.snapshot == sleep, "Permission setup must not change the power mode")
        accessManager.setPasswordlessEnabled(false)
        precondition(!accessManager.passwordlessEnabled)

        let cancelledAccess = PowerManager(
            readSettings: { sleep }, applySettings: { _ in }, requestSleep: {},
            readPasswordlessStatus: { false },
            configurePasswordless: { _ in throw PowerError.accessConfigurationFailed("已取消") }
        )
        cancelledAccess.setPasswordlessEnabled(true)
        precondition(!cancelledAccess.passwordlessEnabled && cancelledAccess.error != nil)
        precondition(cancelledAccess.notice == nil && !cancelledAccess.isConfiguringAccess)

        let failedAccessVerification = PowerManager(
            readSettings: { sleep }, applySettings: { _ in }, requestSleep: {},
            readPasswordlessStatus: { false }, configurePasswordless: { _ in }
        )
        failedAccessVerification.setPasswordlessEnabled(true)
        precondition(!failedAccessVerification.passwordlessEnabled && failedAccessVerification.error != nil,
                     "Configuration must not be declared successful until no-password access is verified")

        print("power manager checks passed")
    }
}
