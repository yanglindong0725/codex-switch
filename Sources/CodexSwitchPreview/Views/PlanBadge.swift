import SwiftUI

/// 账号套餐标签，例如 PLUS、PRO、TEAM。
struct PlanBadge: View {
    enum Prominence {
        case dark
        case light
    }

    let account: CodexAccount
    let prominence: Prominence

    private var planLabel: String? {
        account.normalizedPlan == "unknown" ? nil : account.planLabel
    }

    var body: some View {
        if let planLabel {
            let tint = Color(account.planColor)
            Text(planLabel)
                .font(.system(size: prominence == .dark ? 11 : 10, weight: .bold))
                .foregroundColor(prominence == .dark ? tint : Palette.ink.opacity(0.78))
                .padding(.horizontal, prominence == .dark ? 8 : 7)
                .padding(.vertical, prominence == .dark ? 4 : 3)
                .background(
                    Capsule()
                        .fill(tint.opacity(prominence == .dark ? 0.16 : 0.18))
                )
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(prominence == .dark ? 0.58 : 0.36), lineWidth: 1)
                )
                .lineLimit(1)
        }
    }
}
