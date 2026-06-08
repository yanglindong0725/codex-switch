import SwiftUI

/// 标识当前格式化的是哪一种额度窗口。
enum QuotaKind {
    case primary
    case secondary
}

/// 供视图直接使用的额度展示数据。
///
/// SwiftUI 布局代码不直接处理原始 API 数据。组件只消费这个小结构，因此不需要
/// 关心额度窗口缺失或重置时间为空等细节。
struct QuotaMetric {
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

/// 将 `FetchState` 转成额度视图需要的稳定展示值。
func quotaMetric(state: FetchState, kind: QuotaKind) -> QuotaMetric {
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

/// 每种额度窗口对应的重置时间标题。
func resetTitle(kind: QuotaKind) -> String {
    kind == .primary ? "本次 5h 结束还有" : "本周结束还有"
}

/// 将重置倒计时格式化为紧凑的中文文本。
///
/// 弹窗横向空间很有限，所以这里刻意不显示完整时间戳，只保留天、小时、分钟
/// 级别的信息。
func resetValue(resetsAt: Date?) -> String {
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
