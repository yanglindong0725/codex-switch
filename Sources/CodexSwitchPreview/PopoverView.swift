import SwiftUI

private enum Palette {
    static let ink = Color(red: 0.05, green: 0.06, blue: 0.06)
    static let mutedInk = Color(red: 0.37, green: 0.38, blue: 0.38)
    static let panelTop = Color(red: 0.15, green: 0.17, blue: 0.17)
    static let panelBottom = Color(red: 0.08, green: 0.11, blue: 0.12)
    static let lineDark = Color.white.opacity(0.13)
    static let paper = Color(red: 0.94, green: 0.92, blue: 0.89)
    static let paperLine = Color.black.opacity(0.11)
    static let green = Color(red: 0.53, green: 0.82, blue: 0.42)
    static let mutedGreen = Color(red: 0.60, green: 0.86, blue: 0.46)
    static let track = Color.black.opacity(0.38)
}

public struct CodexSwitchPopoverView: View {
    @ObservedObject var model: SwitcherViewModel
    @State private var showsSettings = false
    @State private var showsRemoveAccounts = false

    public init(model: SwitcherViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            if let active = model.activeAccount {
                ActiveAccountView(
                    account: active,
                    state: model.usageByAlias[active.alias] ?? .idle
                )
            } else {
                EmptyActiveAccountView()
            }

            AccountListView(model: model)

            ActionListView(
                model: model,
                showsRemoveAccounts: $showsRemoveAccounts,
                showsSettings: $showsSettings
            )

            if showsRemoveAccounts {
                RemoveAccountsView(model: model)
            }

            if showsSettings {
                SettingsView(model: model)
            }
        }
        .frame(width: 430)
        .background(Palette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.36), radius: 28, x: 0, y: 18)
    }
}

private struct HeaderView: View {
    var body: some View {
        HStack(spacing: 16) {
            Text("Codex Switch")
                .font(.system(size: 20, weight: .regular, design: .default))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(Palette.green)
                    .frame(width: 8, height: 8)
                Text("在线")
                    .font(.system(size: 14, weight: .regular))
            }
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )

            Image(systemName: "hexagon")
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 17)
        .background(
            LinearGradient(colors: [Palette.panelTop, Palette.panelBottom], startPoint: .top, endPoint: .bottom)
        )
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

private struct ActiveAccountView: View {
    let account: CodexAccount
    let state: FetchState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                AccountAvatar(account: account, isActive: true, size: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(account.alias)
                        .font(.system(size: 24, weight: .semibold))
                    Text(maskEmail(account.email))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.72))
                }

                Spacer()

                Text("当前账号")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.mutedGreen)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.17), lineWidth: 1)
                    )
            }
            .padding(.bottom, 16)

            DividerLine(color: Palette.lineDark)

            QuotaGauge(label: "5h", metric: quotaMetric(state: state, kind: .primary))
                .padding(.vertical, 17)
            DividerLine(color: Palette.lineDark)
            QuotaGauge(label: "周", metric: quotaMetric(state: state, kind: .secondary))
                .padding(.vertical, 17)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .background(
            LinearGradient(colors: [Palette.panelBottom, Color(red: 0.10, green: 0.12, blue: 0.12)], startPoint: .top, endPoint: .bottom)
        )
    }
}

private struct EmptyActiveAccountView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("未发现账号")
                .font(.system(size: 21, weight: .semibold))
            Text("点击“添加账号...”开始登录。")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundColor(.white)
        .padding(22)
        .background(Palette.panelBottom)
    }
}

private struct AccountListView: View {
    @ObservedObject var model: SwitcherViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.otherAccounts, id: \.alias) { account in
                Button {
                    model.actions.switchAccount(account.alias)
                } label: {
                    OtherAccountRow(account: account, state: model.usageByAlias[account.alias] ?? .idle)
                }
                .buttonStyle(.plain)

                DividerLine(color: Palette.paperLine)
                    .padding(.horizontal, 18)
            }
        }
        .background(Palette.paper)
    }
}

private struct OtherAccountRow: View {
    let account: CodexAccount
    let state: FetchState

    var body: some View {
        HStack(spacing: 12) {
            AccountAvatar(account: account, isActive: false, size: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text(account.alias)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(maskEmail(account.email))
                    .font(.system(size: 15))
                    .foregroundColor(Palette.mutedInk)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                CompactQuotaLine(label: "5h", metric: quotaMetric(state: state, kind: .primary))
                CompactQuotaLine(label: "周", metric: quotaMetric(state: state, kind: .secondary))
            }
            .frame(width: 72, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(Palette.ink.opacity(0.56))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
        .contentShape(Rectangle())
    }
}

private struct ActionListView: View {
    @ObservedObject var model: SwitcherViewModel
    @Binding var showsRemoveAccounts: Bool
    @Binding var showsSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            ActionRow(icon: "arrow.clockwise", title: "刷新全部", shortcut: "⌘R") {
                model.actions.refreshUsage()
            }

            DividerLine(color: Palette.paperLine).padding(.horizontal, 18)

            ActionRow(icon: "plus.circle", title: "添加账号...", shortcut: "⌘N") {
                model.actions.addAccount()
            }

            DividerLine(color: Palette.paperLine).padding(.horizontal, 18)

            ActionRow(icon: "minus.circle", title: "移除账号", shortcut: "⌫") {
                withAnimation(.easeInOut(duration: 0.16)) { showsRemoveAccounts.toggle() }
            }

            DividerLine(color: Palette.paperLine)

            ToggleRow(model: model)

            DividerLine(color: Palette.paperLine).padding(.horizontal, 18)

            ActionRow(icon: "gearshape", title: "设置", shortcut: "⌘,") {
                withAnimation(.easeInOut(duration: 0.16)) { showsSettings.toggle() }
            }

            DividerLine(color: Palette.paperLine).padding(.horizontal, 18)

            ActionRow(icon: "power", title: "退出", shortcut: "⌘Q") {
                model.actions.quit()
            }
        }
        .background(Palette.paper)
    }
}

private struct ToggleRow: View {
    @ObservedObject var model: SwitcherViewModel

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.square")
                .font(.system(size: 18, weight: .regular))
                .frame(width: 28)
            Text("登录时启动")
                .font(.system(size: 16, weight: .regular))
            Spacer()
            Toggle("", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.actions.setLaunchAtLogin($0) }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle())
            .accentColor(Color(red: 0.18, green: 0.68, blue: 0.28))
        }
        .foregroundColor(Palette.ink)
        .padding(.horizontal, 18)
        .frame(height: 44)
    }
}

private struct ActionRow: View {
    let icon: String
    let title: String
    let shortcut: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                Spacer()
                Text(shortcut)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.ink.opacity(0.55))
            }
            .foregroundColor(Palette.ink)
            .padding(.horizontal, 18)
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RemoveAccountsView: View {
    @ObservedObject var model: SwitcherViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.otherAccounts, id: \.alias) { account in
                Button {
                    model.actions.deleteAccount(account.alias)
                } label: {
                    HStack {
                        Text("移除 \(account.alias)")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: "trash")
                    }
                    .foregroundColor(.red.opacity(0.88))
                    .padding(.horizontal, 22)
                    .frame(height: 34)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(red: 0.99, green: 0.96, blue: 0.94))
        .overlay(DividerLine(color: Palette.paperLine), alignment: .top)
    }
}

private struct SettingsView: View {
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

private struct SettingGroup<Content: View>: View {
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

private struct PickerRow: View {
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

private struct ModePicker: View {
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

private struct ChipButtonStyle: ButtonStyle {
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

private struct QuotaGauge: View {
    let label: String
    let metric: QuotaMetric

    var body: some View {
        let barWidth: CGFloat = 196

        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 19, weight: .regular))
                .frame(width: 42, alignment: .leading)

            VStack(spacing: 6) {
                HStack {
                    Text("剩余额度")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.78))
                    Spacer()
                    Text(metric.remainingPercentText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Palette.mutedGreen)
                }

                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.track)
                    Capsule().fill(Palette.green).frame(width: barWidth * metric.fraction)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 3, height: 10)
                        .cornerRadius(1.5)
                        .offset(x: max(0, barWidth * metric.fraction - 2))
                }
                .frame(width: barWidth, height: 4)

                HStack(spacing: 0) {
                    Text("0%")
                    Spacer()
                    Text(metric.middleLabel)
                    Spacer()
                    Text("100%")
                }
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.78))
                .overlay(
                    TickMarks()
                        .stroke(Color.white.opacity(0.55), lineWidth: 0.8)
                        .frame(height: 7)
                        .offset(y: -7)
                )
            }
            .frame(width: barWidth)

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.72))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.resetTitle)
                    Text(metric.resetValue)
                }
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.72))
            }
            .frame(width: 124, alignment: .leading)
        }
    }
}

private struct CompactQuotaLine: View {
    let label: String
    let metric: QuotaMetric

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 20, alignment: .leading)
            Text(metric.remainingValueText)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Palette.mutedInk)
        }
    }
}

private struct AccountAvatar: View {
    let account: CodexAccount
    let isActive: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.20, green: 0.22, blue: 0.23), Color(red: 0.04, green: 0.05, blue: 0.05)],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: size
                    )
                )
                .overlay(Circle().stroke(Color.white.opacity(isActive ? 0.16 : 0.08), lineWidth: 1))
                .frame(width: size, height: size)

            Text(String(account.alias.prefix(1)).uppercased())
                .font(.system(size: isActive ? 25 : 23, weight: .medium))
                .foregroundColor(isActive ? Palette.mutedGreen : .white.opacity(0.92))

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(isActive ? Palette.green : Color.gray.opacity(0.75))
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(isActive ? Palette.panelBottom : Palette.paper, lineWidth: 2))
                        .offset(x: 1, y: 1)
                }
            }
        }
        .frame(width: size + 2, height: size + 2)
    }
}

private struct DividerLine: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

private struct TickMarks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0...12 {
            let x = rect.minX + rect.width * CGFloat(index) / 12
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        return path
    }
}

private enum QuotaKind {
    case primary
    case secondary
}

private struct QuotaMetric {
    let fraction: CGFloat
    let middleLabel: String
    let remainingPercentText: String
    let remainingValueText: String
    let resetTitle: String
    let resetValue: String

    static func unavailable(kind: QuotaKind) -> QuotaMetric {
        QuotaMetric(
            fraction: 0,
            middleLabel: "50%",
            remainingPercentText: "等待刷新",
            remainingValueText: "--",
            resetTitle: kind == .primary ? "本次 5h 结束" : "本周结束",
            resetValue: "等待刷新"
        )
    }
}

private func quotaMetric(state: FetchState, kind: QuotaKind) -> QuotaMetric {
    guard case .success(let info) = state else { return .unavailable(kind: kind) }
    let window = kind == .primary ? info.primary : info.secondary
    guard let window else { return .unavailable(kind: kind) }

    let used = min(max(window.usedPercent, 0), 100)
    let remaining = 100 - used
    return QuotaMetric(
        fraction: CGFloat(remaining) / 100,
        middleLabel: "50%",
        remainingPercentText: "剩余 \(remaining)%",
        remainingValueText: "\(remaining)%",
        resetTitle: resetTitle(kind: kind),
        resetValue: resetValue(resetsAt: window.resetsAt)
    )
}

private func resetTitle(kind: QuotaKind) -> String {
    kind == .primary ? "本次 5h 结束还有" : "本周结束还有"
}

private func resetValue(resetsAt: Date?) -> String {
    guard let resetsAt else { return "时间未知" }
    let seconds = max(0, Int(resetsAt.timeIntervalSince(Date())))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60

    let days = hours / 24
    let restHours = hours % 24
    if days > 0 {
        return "\(days)天\(restHours)小时"
    }
    if hours > 0 {
        return "\(hours)小时\(minutes)分"
    }
    return "\(max(minutes, 1))分钟"
}

private func maskEmail(_ email: String) -> String {
    guard email != "?", let atIndex = email.firstIndex(of: "@") else { return email }
    let name = String(email[..<atIndex])
    let domain = String(email[atIndex...])
    let first = name.first.map(String.init) ?? "?"
    return "\(first)***\(domain)"
}

#if DEBUG
private extension SwitcherActions {
    static let preview = SwitcherActions(
        refreshUsage: {},
        addAccount: {},
        switchAccount: { _ in },
        deleteAccount: { _ in },
        setLaunchAtLogin: { _ in },
        setRefreshInterval: { _ in },
        setAlert5hThreshold: { _ in },
        setAlertWeekThreshold: { _ in },
        setRestartCodexAfterSwitch: { _ in },
        quit: {}
    )
}

private extension SwitcherViewModel {
    static func preview() -> SwitcherViewModel {
        let model = SwitcherViewModel(actions: .preview)
        let now = Date()
        let accounts = [
            CodexAccount(
                alias: "yanglindongwe",
                email: "yanglindongwe@gmail.com",
                plan: "pro",
                authMode: "oauth",
                accountId: "preview-active",
                accessToken: "",
                subscriptionStart: nil,
                subscriptionUntil: nil,
                daysRemaining: nil,
                tokenExpiry: nil
            ),
            CodexAccount(
                alias: "liny278591",
                email: "liny27859@gmail.com",
                plan: "plus",
                authMode: "oauth",
                accountId: "preview-secondary",
                accessToken: "",
                subscriptionStart: nil,
                subscriptionUntil: nil,
                daysRemaining: nil,
                tokenExpiry: nil
            ),
            CodexAccount(
                alias: "workbench",
                email: "workbench@example.com",
                plan: "team",
                authMode: "oauth",
                accountId: "preview-team",
                accessToken: "",
                subscriptionStart: nil,
                subscriptionUntil: nil,
                daysRemaining: nil,
                tokenExpiry: nil
            )
        ]

        model.currentAlias = "yanglindongwe"
        model.accounts = accounts
        model.usageByAlias = [
            "yanglindongwe": .success(RateLimitInfo(
                primary: RateLimitWindow(usedPercent: 34, resetsAt: now.addingTimeInterval(4 * 3600 + 23 * 60)),
                secondary: RateLimitWindow(usedPercent: 24, resetsAt: now.addingTimeInterval(5 * 24 * 3600 + 21 * 3600)),
                credits: nil,
                planType: "pro"
            )),
            "liny278591": .success(RateLimitInfo(
                primary: RateLimitWindow(usedPercent: 1, resetsAt: now.addingTimeInterval(4 * 3600 + 59 * 60)),
                secondary: RateLimitWindow(usedPercent: 68, resetsAt: now.addingTimeInterval(5 * 24 * 3600 + 17 * 3600)),
                credits: nil,
                planType: "plus"
            )),
            "workbench": .loading
        ]
        model.config = AppConfig(
            refreshIntervalMinutes: 15,
            minRefreshIntervalSeconds: 60,
            alert5hThreshold: 20,
            alertWeekThreshold: 10,
            restartCodexAfterSwitch: .ask
        )
        model.launchAtLogin = true
        return model
    }
}

#Preview("Popover") {
    CodexSwitchPopoverView(model: .preview())
}
#endif
