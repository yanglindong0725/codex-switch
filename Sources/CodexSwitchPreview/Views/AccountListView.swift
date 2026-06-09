import SwiftUI

/// 非当前账号列表。
///
/// 点击账号行只会进入确认态，真正切换由展开面板里的确认按钮触发。这样保留
/// 菜单栏弹窗的紧凑性，同时避免误触后立刻切换账号。
struct AccountListView: View {
    @ObservedObject var model: SwitcherViewModel
    @Binding var pendingSwitchAlias: String?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.otherAccounts, id: \.alias) { account in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        pendingSwitchAlias = pendingSwitchAlias == account.alias ? nil : account.alias
                    }
                } label: {
                    OtherAccountRow(
                        account: account,
                        state: model.usageByAlias[account.alias] ?? .idle,
                        isPendingSwitch: pendingSwitchAlias == account.alias
                    )
                }
                .buttonStyle(.plain)

                if pendingSwitchAlias == account.alias {
                    SwitchConfirmationView(
                        account: account,
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                pendingSwitchAlias = nil
                            }
                        },
                        onConfirm: {
                            pendingSwitchAlias = nil
                            model.actions.switchAccount(account.alias)
                        }
                    )
                }

                DividerLine(color: Palette.paperLine)
                    .padding(.horizontal, 18)
            }
        }
        .background(Palette.paper)
    }
}

/// 浅色账号列表中的单行账号。
///
/// 调 `.padding(.vertical, 17)` 可以改行高，调 `.frame(width: 72)` 可以改右侧
/// 紧凑额度列宽。账号名/邮箱区域设置了布局优先级，长名称会截断，不会把额度列
/// 挤到错位。
struct OtherAccountRow: View {
    let account: CodexAccount
    let state: FetchState
    let isPendingSwitch: Bool

    var body: some View {
        HStack(spacing: 12) {
            AccountAvatar(account: account, isActive: false, size: 52)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(account.alias)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    PlanBadge(account: account, prominence: .light)
                }
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

            Image(systemName: isPendingSwitch ? "arrow.right.circle.fill" : "chevron.right")
                .font(.system(size: isPendingSwitch ? 22 : 20, weight: isPendingSwitch ? .semibold : .regular))
                .foregroundColor(isPendingSwitch ? Palette.green : Palette.ink.opacity(0.56))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
        .background(isPendingSwitch ? Palette.green.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
    }
}

/// 账号行展开后的切换确认面板。
struct SwitchConfirmationView: View {
    let account: CodexAccount
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("切换到 \(account.alias)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    PlanBadge(account: account, prominence: .light)
                }
                Text(maskEmail(account.email))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Palette.mutedInk)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)

            Spacer()

            Button(action: onCancel) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                    Text("取消")
                }
            }
            .buttonStyle(SwitchDecisionButtonStyle(tone: .quiet))

            Button(action: onConfirm) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                    Text("切换")
                }
            }
            .buttonStyle(SwitchDecisionButtonStyle(tone: .primary))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Palette.panelBottom.opacity(0.08))
    }
}

struct SwitchDecisionButtonStyle: ButtonStyle {
    enum Tone {
        case quiet
        case primary
    }

    let tone: Tone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(tone == .primary ? Palette.paper : Palette.ink.opacity(0.76))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tone == .primary ? Palette.ink : Color.white.opacity(0.46))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
