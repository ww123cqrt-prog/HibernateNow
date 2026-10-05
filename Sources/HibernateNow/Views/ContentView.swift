import AppKit
import Combine
import SwiftUI

// The macOS 27 command-line SDK exposes @State macros without their plugin.
// This alias selects the existing property wrapper, also available on macOS 14.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct ContentView: View {
    @EnvironmentObject private var manager: PowerManager
    @ViewState private var showKeepRunningConfirmation = false
    @ViewState private var showPasswordlessConfirmation = false

    private var isBusy: Bool { manager.isApplying || manager.isConfiguringAccess }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("电源管理")
                        .font(.title2.bold())
                    Text("选择合盖后的电脑行为")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    manager.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("重新读取系统状态")
                .keyboardShortcut("r", modifiers: .command)
                .disabled(isBusy)
            }

            statusPanel

            accessPanel

            VStack(alignment: .leading, spacing: 10) {
                Text("选择档位")
                    .font(.headline)
                ForEach(LidMode.allCases) { mode in
                    modeRow(mode)
                }
            }

            if let error = manager.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            } else if let notice = manager.notice {
                Label(notice, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }

            HStack {
                Button("立即睡眠") {
                    manager.sleepNow()
                }
                .disabled(manager.snapshot?.sleepDisabled != false || !manager.passwordlessEnabled || isBusy)
                .help("按当前档位立即进入 macOS 睡眠；合盖继续运行时不可用")

                Spacer()

                Button("应用此档") {
                    if manager.selectedMode == .keepRunning {
                        showKeepRunningConfirmation = true
                    } else {
                        manager.applySelected()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy || manager.snapshot == nil || !manager.passwordlessEnabled)
                .keyboardShortcut(.defaultAction)
            }

            Text("设置对接电源和电池供电均生效。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 580)
        .alert("合盖后电脑会继续运行", isPresented: $showKeepRunningConfirmation) {
            Button("取消", role: .cancel) {}
            Button("确认开启") { manager.applySelected() }
        } message: {
            Text("此档位会阻止合盖和空闲自动休眠，电池供电时也生效。退出软件后设置仍会保留；放入背包前请切换到休眠或睡眠。")
        }
        .alert("启用免密切换", isPresented: $showPasswordlessConfirmation) {
            Button("取消", role: .cancel) {}
            Button("授权并启用") { manager.setPasswordlessEnabled(true) }
        } message: {
            Text("接下来只需一次系统管理员授权。本账号将获准免密执行三档电源切换、立即睡眠及配置核对；本账号的其他程序也可调用这些固定命令。不会保存你的密码。可随时在应用里关闭免密权限。")
        }
    }

    private var accessPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(manager.passwordlessEnabled ? "免密切换已启用" : "首次使用需要授权", systemImage: manager.passwordlessEnabled ? "lock.open" : "lock")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(manager.passwordlessEnabled ? "关闭免密" : "启用免密切换") {
                    if manager.passwordlessEnabled {
                        manager.setPasswordlessEnabled(false)
                    } else {
                        showPasswordlessConfirmation = true
                    }
                }
                .disabled(isBusy)
            }
            Text(manager.passwordlessEnabled ? "可右键 Dock 图标直接选档，切换无需输入密码。" : "授权一次，之后切换无需输入密码。权限只涵盖本账号的固定电源命令。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("上次读取的电源配置")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(manager.snapshot?.powerSource ?? "未确认")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(manager.snapshot == nil ? "当前配置未确认" : (manager.snapshot?.lidMode?.title ?? "自定义或未知配置"))
                .font(.title3.bold())
            if let snapshot = manager.snapshot {
                Text("电池休眠参数 \(snapshot.batteryHibernateMode) · 接电源休眠参数 \(snapshot.acHibernateMode) · 禁止系统睡眠 \(snapshot.sleepDisabled ? "开" : "关")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func modeRow(_ mode: LidMode) -> some View {
        let selected = manager.selectedMode == mode
        return Button {
            manager.selectedMode = mode
            manager.notice = nil
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: mode.symbol)
                    .font(.title2)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                    Text(mode.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .background(selected ? Color.accentColor.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.22), lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(mode.title + "。" + mode.detail)
    }
}
