import SwiftUI

/// 可展开的设置面板。
///
/// 只有真实运行时偏好才应该加到这里。每个 chip 的视觉样式在文件底部的
/// `ChipButtonStyle` 中控制。
struct SettingsView: View {
    @ObservedObject var model: SwitcherViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingGroup(title: "自动刷新") {
                PickerRow(options: [("5 分钟", 5), ("15 分钟", 15), ("30 分钟", 30), ("1 小时", 60), ("关闭", 0)],
                          selected: model.config.refreshIntervalMinutes) { model.actions.setRefreshInterval($0) }
            }
            SettingGroup(title: "5 小时提醒") {
                PickerRow(options: [("10%", 10), ("20%", 20), ("30%", 30), ("50%", 50)],
                          selected: model.config.alert5hThreshold) { model.actions.setAlert5hThreshold($0) }
            }
            SettingGroup(title: "每周提醒") {
                PickerRow(options: [("5%", 5), ("10%", 10), ("20%", 20), ("30%", 30)],
                          selected: model.config.alertWeekThreshold) { model.actions.setAlertWeekThreshold($0) }
            }
            SettingGroup(title: "切换账号后") {
                ModePicker(selected: model.config.restartCodexAfterSwitch) {
                    model.actions.setRestartCodexAfterSwitch($0)
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.93, green: 0.90, blue: 0.86))
        .overlay(DividerLine(color: Palette.paperLine), alignment: .top)
    }
}

/// 设置分组的“标题 + 内容”包装视图。
struct SettingGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Palette.ink.opacity(0.58))
            content
        }
    }
}

/// 刷新间隔和提醒阈值共用的整数选项行。
struct PickerRow: View {
    let options: [(String, Int)]
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.1) { option in
                Button(option.0) { onSelect(option.1) }
                    .buttonStyle(ChipButtonStyle(isSelected: selected == option.1))
            }
        }
    }
}

/// 切换账号后处理方式选择器，使用强类型枚举而不是整数值。
struct ModePicker: View {
    let selected: RestartCodexAfterSwitch
    let onSelect: (RestartCodexAfterSwitch) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button("询问") { onSelect(.ask) }
                .buttonStyle(ChipButtonStyle(isSelected: selected == .ask))
            Button("自动") { onSelect(.auto) }
                .buttonStyle(ChipButtonStyle(isSelected: selected == .auto))
            Button("不处理") { onSelect(.off) }
                .buttonStyle(ChipButtonStyle(isSelected: selected == .off))
        }
    }
}

/// 设置选项使用的小胶囊样式。
///
/// 修改这里的选中/未选中颜色，会影响所有设置 chip。
struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(isSelected ? Palette.paper : Palette.ink.opacity(0.72))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isSelected ? Palette.ink : Color.white.opacity(0.42))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
