import Foundation

enum LidMode: String, CaseIterable, Identifiable {
    case hibernate
    case sleep
    case keepRunning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hibernate: "合盖休眠"
        case .sleep: "合盖睡眠"
        case .keepRunning: "合盖继续运行"
        }
    }

    var detail: String {
        switch self {
        case .hibernate:
            "更省电的休眠设置。"
        case .sleep:
            "普通睡眠设置。睡眠时应用会暂停，网络可能中断。"
        case .keepRunning:
            "阻止系统睡眠。电池会持续耗电，请注意散热。"
        }
    }

    var symbol: String {
        switch self {
        case .hibernate: "moon.zzz.fill"
        case .sleep: "moon.fill"
        case .keepRunning: "laptopcomputer"
        }
    }

    // Exact argument lists are also used to restrict the one-time sudoers rule.
    var pmsetArguments: [String] {
        switch self {
        case .hibernate:
            ["-a", "hibernatemode", "25", "disablesleep", "0"]
        case .sleep:
            ["-a", "hibernatemode", "3", "disablesleep", "0"]
        case .keepRunning:
            ["-a", "hibernatemode", "3", "disablesleep", "1"]
        }
    }
}
