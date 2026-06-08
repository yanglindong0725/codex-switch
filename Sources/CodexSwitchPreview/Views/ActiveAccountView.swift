import SwiftUI

/// 深色的当前账号摘要区域。
///
/// 这是弹窗里最大的视觉区域。头像尺寸、账号文字、当前账号标签，以及两条额度行
/// 的垂直间距都在这里调整。
struct ActiveAccountView: View {
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

/// 没有可用账号时显示的空状态。
///
/// 视觉上保持和 `ActiveAccountView` 接近，避免添加账号前后弹窗风格突然变化。
struct EmptyActiveAccountView: View {
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
