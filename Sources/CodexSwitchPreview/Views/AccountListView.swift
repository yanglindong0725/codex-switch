import SwiftUI

/// 非当前账号列表。
///
/// 每一行都是按钮，因为点击会切换账号。行布局应保持紧凑：这里仍然是菜单栏
/// 弹窗，不是完整账号管理页面。
struct AccountListView: View {
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

/// 浅色账号列表中的单行账号。
///
/// 调 `.padding(.vertical, 17)` 可以改行高，调 `.frame(width: 72)` 可以改右侧
/// 紧凑额度列宽。账号名/邮箱区域设置了布局优先级，长名称会截断，不会把额度列
/// 挤到错位。
struct OtherAccountRow: View {
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
