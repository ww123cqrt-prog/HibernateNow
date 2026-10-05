import Foundation

struct PrivilegedPowerControl {
    func apply(_ mode: LidMode) throws {
        try PasswordlessPowerAccess().runPMSet(mode.pmsetArguments)
    }

    func sleepNow() throws {
        try PasswordlessPowerAccess().runPMSet(["sleepnow"])
    }
}
