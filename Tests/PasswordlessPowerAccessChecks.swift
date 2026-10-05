import AppKit

@main
struct PasswordlessPowerAccessChecks {
    static func main() throws {
        var calls: [[String]] = []
        var authorizations = 0
        let access = PasswordlessPowerAccess(
            userID: 501,
            runSudo: { arguments in
                calls.append(arguments)
                return .init(status: 0, output: "")
            },
            authorize: { _ in authorizations += 1 }
        )
        for mode in LidMode.allCases {
            try access.runPMSet(mode.pmsetArguments)
        }
        precondition(calls.count == 3)
        precondition(calls.allSatisfy { Array($0.prefix(4)) == ["-n", "-k", "--", "/usr/bin/pmset"] },
                     "Every switch must forbid password prompting and ignore cached credentials")
        precondition(authorizations == 0, "Switches must never request administrator authorization")

        for forbidden in [["-a", "hibernatemode", "0"], ["-a", "disablesleep", "1"],
                          ["-a", "hibernatefile", "/tmp/image"], ["sleepnow", "extra"]] {
            let before = calls.count
            do {
                try access.runPMSet(forbidden)
                preconditionFailure("An unapproved command was accepted")
            } catch PowerError.passwordlessUnavailable {
                precondition(calls.count == before, "Reject unsupported arguments before execution")
            }
        }
        let denied = PasswordlessPowerAccess(
            userID: 501,
            runSudo: { _ in .init(status: 1, output: "sudo: a password is required") },
            authorize: { _ in authorizations += 1 }
        )
        do {
            try denied.runPMSet(LidMode.sleep.pmsetArguments)
            preconditionFailure("Denied execution was treated as success")
        } catch PowerError.passwordlessUnavailable {
            precondition(authorizations == 0, "A failure must not fall back to a password dialog")
        }

        let rule = try PasswordlessPowerAccess.sudoersRule(userID: 501)
        precondition(rule.contains("#501 ALL=(root) NOPASSWD: NOSETENV:"))
        precondition(!rule.contains("NOPASSWD: ALL") && !rule.contains("*"))
        let expected = Set([
            "/usr/bin/pmset -a hibernatemode 25 disablesleep 0",
            "/usr/bin/pmset -a hibernatemode 3 disablesleep 0",
            "/usr/bin/pmset -a hibernatemode 3 disablesleep 1",
            "/usr/bin/pmset sleepnow", "/usr/bin/pmset -g"
        ])
        let actual = Set(rule.components(separatedBy: "NOSETENV: ")[1]
            .trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: ", "))
        precondition(actual == expected, "The rule must allow only the reviewed, exact operations")
        try rule.write(toFile: ".build/passwordless-rule-check", atomically: true, encoding: .utf8)
        try PasswordlessPowerAccess.setupScript(userID: 501, enabled: true)
            .write(toFile: ".build/passwordless-enable-check.sh", atomically: true, encoding: .utf8)
        try PasswordlessPowerAccess.setupScript(userID: 501, enabled: false)
            .write(toFile: ".build/passwordless-disable-check.sh", atomically: true, encoding: .utf8)
        do {
            _ = try PasswordlessPowerAccess.sudoersRule(userID: 0)
            preconditionFailure("Root must not be configured as the app user")
        } catch PowerError.accessConfigurationFailed {}

        let text = "quote \" backslash \\ newline\nend"
        let harmless = "printf '%s' " + "'" + text + "'"
        let script = NSAppleScript(source: "do shell script " + PasswordlessPowerAccess.appleScriptLiteral(harmless) + " without altering line endings")!
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        precondition(error == nil && result.stringValue == text, "Shell text must survive AppleScript quoting")
        print("passwordless access checks passed")
    }
}
