import AppKit
import Darwin

struct PasswordlessPowerAccess {
    struct CommandResult {
        let status: Int32
        let output: String
    }

    private let userID: uid_t
    private let runSudo: ([String]) throws -> CommandResult
    private let authorize: (String) throws -> Void

    init(
        userID: uid_t = getuid(),
        runSudo: @escaping ([String]) throws -> CommandResult = Self.runSudoProcess,
        authorize: @escaping (String) throws -> Void = Self.runAsAdministrator
    ) {
        self.userID = userID
        self.runSudo = runSudo
        self.authorize = authorize
    }

    private static var allowedArguments: [[String]] {
        LidMode.allCases.map(\.pmsetArguments) + [["sleepnow"], ["-g"]]
    }

    private static func rulePath(userID: uid_t) -> String {
        "/private/etc/sudoers.d/cq-hibernatenow-\(userID)"
    }

    var isEnabled: Bool {
        var info = stat()
        guard userID != 0,
              lstat(Self.rulePath(userID: userID), &info) == 0,
              info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == 0, info.st_gid == 0,
              info.st_mode & 0o777 == 0o440 else { return false }
        // A harmless read proves that no cached password is being relied on.
        return (try? runSudo(["-n", "-k", "--", "/usr/bin/pmset", "-g"]).status) == 0
    }

    func configure(enabled: Bool) throws {
        try authorize(Self.setupScript(userID: userID, enabled: enabled))
        guard isEnabled == enabled else {
            throw PowerError.accessConfigurationFailed("系统未确认所请求的免密权限，请刷新后重试")
        }
    }

    func runPMSet(_ arguments: [String]) throws {
        guard Self.allowedArguments.contains(arguments) else {
            throw PowerError.passwordlessUnavailable("不支持的电源命令")
        }
        let result = try runSudo(["-n", "-k", "--", "/usr/bin/pmset"] + arguments)
        guard result.status == 0 else {
            throw PowerError.passwordlessUnavailable(result.output)
        }
    }

    static func sudoersRule(userID: uid_t) throws -> String {
        guard userID != 0 else { throw PowerError.accessConfigurationFailed("请以普通本机账号运行应用") }
        let commands = allowedArguments.map { "/usr/bin/pmset " + $0.joined(separator: " ") }
        return "# Managed by com.cq.HibernateNow; exact power operations only.\n" +
            "#\(userID) ALL=(root) NOPASSWD: NOSETENV: " + commands.joined(separator: ", ") + "\n"
    }

    static func setupScript(userID: uid_t, enabled: Bool) throws -> String {
        let rule = try sudoersRule(userID: userID)
        let operation: String
        if enabled {
            operation = """
            temp=$(/usr/bin/mktemp "$directory/.cq-hibernatenow-\(userID).XXXXXX")
            printf '%s' \(shellLiteral(rule)) > "$temp"
            /usr/sbin/chown root:wheel "$temp"
            /bin/chmod 0440 "$temp"
            /usr/sbin/visudo -c -f "$temp" >/dev/null
            if [ -f "$rule" ]; then
              backup=$(/usr/bin/mktemp "$directory/.cq-hibernatenow-backup-\(userID).XXXXXX")
              /bin/cp -p "$rule" "$backup"
            fi
            /bin/mv "$temp" "$rule"
            changed=1
            """
        } else {
            operation = """
            if [ ! -f "$rule" ]; then exit 0; fi
            backup=$(/usr/bin/mktemp "$directory/.cq-hibernatenow-backup-\(userID).XXXXXX")
            /bin/mv "$rule" "$backup"
            changed=1
            """
        }
        return """
        set -eu
        directory='/private/etc/sudoers.d'
        rule=\(shellLiteral(rulePath(userID: userID)))
        if [ -L "$directory" ] || [ ! -d "$directory" ] ||
           [ "$(/usr/bin/stat -f '%u:%g:%Lp' "$directory")" != '0:0:755' ]; then
          printf '%s\\n' '系统 sudoers 目录权限不符合要求' >&2; exit 1
        fi
        if [ -L "$rule" ] || { [ -e "$rule" ] && [ ! -f "$rule" ]; }; then
          printf '%s\\n' '免密规则路径不是普通文件' >&2; exit 1
        fi
        if ! /usr/bin/grep -Eq '^[[:space:]]*[@#]includedir[[:space:]]+(/private)?/etc/sudoers[.]d[[:space:]]*$' /private/etc/sudoers; then
          printf '%s\\n' '系统没有启用 sudoers.d；未修改系统主配置' >&2; exit 1
        fi
        /usr/sbin/visudo -c >/dev/null
        temp=''; backup=''; changed=0; success=0
        cleanup() {
          if [ "$changed" = 1 ] && [ "$success" = 0 ]; then
            if [ -n "$backup" ] && [ -f "$backup" ]; then
              /bin/mv "$backup" "$rule"
            elif [ -f "$rule" ]; then
              /bin/rm "$rule"
            fi
          fi
          if [ -n "$temp" ] && [ -f "$temp" ]; then /bin/rm "$temp"; fi
          if [ -n "$backup" ] && [ -f "$backup" ]; then /bin/rm "$backup"; fi
        }
        trap cleanup EXIT
        \(operation)
        /usr/sbin/visudo -c >/dev/null
        success=1
        """
    }

    private static func shellLiteral(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptLiteral(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n") + "\""
    }

    private static func runAsAdministrator(_ command: String) throws {
        guard let script = NSAppleScript(source: "do shell script " + appleScriptLiteral(command) + " with administrator privileges") else {
            throw PowerError.accessConfigurationFailed("无法创建一次性管理员授权请求")
        }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
        if let error {
            throw PowerError.accessConfigurationFailed(
                error["NSAppleScriptErrorMessage"] as? String ?? "授权已取消或设置失败"
            )
        }
    }

    private static func runSudoProcess(_ arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = arguments
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "C", "LC_ALL": "C"]
        process.currentDirectoryURL = URL(fileURLWithPath: "/")
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        output.fileHandleForWriting.closeFile()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus,
                             output: String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
