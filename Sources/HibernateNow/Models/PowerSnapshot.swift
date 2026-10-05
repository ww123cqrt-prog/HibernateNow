import Foundation

struct PowerSnapshot: Equatable {
    let sleepDisabled: Bool
    let batteryHibernateMode: Int
    let acHibernateMode: Int
    let powerSource: String

    var lidMode: LidMode? {
        if sleepDisabled { return .keepRunning }
        if batteryHibernateMode == 25 && acHibernateMode == 25 { return .hibernate }
        if batteryHibernateMode == 3 && acHibernateMode == 3 { return .sleep }
        return nil
    }

    func matchesTarget(_ mode: LidMode) -> Bool {
        switch mode {
        case .hibernate:
            !sleepDisabled && batteryHibernateMode == 25 && acHibernateMode == 25
        case .sleep:
            !sleepDisabled && batteryHibernateMode == 3 && acHibernateMode == 3
        case .keepRunning:
            sleepDisabled && batteryHibernateMode == 3 && acHibernateMode == 3
        }
    }

    static func parse(live: String, custom: String, source: String) throws -> PowerSnapshot {
        let liveLines = live.split(separator: "\n").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard liveLines.contains("Currently in use:"),
              liveLines.contains(where: { line in
                  let words = line.split(whereSeparator: \.isWhitespace)
                  return words.count >= 2 && words[0] == "hibernatemode" && Int(words[1]) != nil
              }) else {
            throw PowerError.unreadableSettings
        }

        var sleepDisabled = false
        var sawSleepDisabled = false
        for line in liveLines {
            let words = line.split(whereSeparator: \.isWhitespace)
            guard words.first?.lowercased() == "sleepdisabled" else { continue }
            guard !sawSleepDisabled, words.count >= 2, words[1] == "0" || words[1] == "1" else {
                throw PowerError.unreadableSettings
            }
            sawSleepDisabled = true
            sleepDisabled = words[1] == "1"
        }

        var batteryMode: Int?
        var acMode: Int?
        var section: String?

        for line in custom.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(":") {
                section = trimmed == "Battery Power:" ? "battery" :
                    (trimmed == "AC Power:" ? "ac" : nil)
                continue
            }
            let words = trimmed.split(whereSeparator: \.isWhitespace)
            guard let section, words.first == "hibernatemode" else { continue }
            guard words.count == 2, let value = Int(words[1]) else {
                throw PowerError.unreadableSettings
            }
            if section == "battery" {
                guard batteryMode == nil else { throw PowerError.unreadableSettings }
                batteryMode = value
            } else {
                guard acMode == nil else { throw PowerError.unreadableSettings }
                acMode = value
            }
        }

        guard let batteryMode, let acMode else { throw PowerError.unreadableSettings }
        let currentSource = source.contains("AC Power") ? "接电源" :
            (source.contains("Battery Power") ? "电池" : "未知电源")
        return PowerSnapshot(
            sleepDisabled: sleepDisabled,
            batteryHibernateMode: batteryMode,
            acHibernateMode: acMode,
            powerSource: currentSource
        )
    }
}

enum PowerError: LocalizedError {
    case unreadableSettings
    case commandFailed(String)
    case verificationFailed
    case authorizationFailed(String)
    case passwordlessUnavailable(String)
    case accessConfigurationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadableSettings:
            "无法确认当前电源设置；如果刚刚操作，参数可能已改变。"
        case .commandFailed(let detail):
            "读取电源设置失败：\(detail)"
        case .verificationFailed:
            "命令已返回，但系统读回的目标参数不一致。请查看当前配置。"
        case .authorizationFailed(let detail):
            "设置命令未完成，当前参数需核对：\(detail)"
        case .passwordlessUnavailable(let detail):
            "免密命令未完成，请核对当前配置；如权限失效，请重新启用免密切换。\(detail)"
        case .accessConfigurationFailed(let detail):
            "免密权限设置未完成：\(detail)"
        }
    }
}
