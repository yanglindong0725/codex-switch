import SwiftUI

/// 当前账号深色区域里使用的完整额度条。
///
/// 固定的 `barWidth` 和右侧重置时间宽度用于保持两条额度行对齐。如果弹窗宽度变化，
/// 优先从这里重新平衡布局。
struct QuotaGauge: View {
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

/// 非当前账号行里使用的紧凑两列额度文本。
struct CompactQuotaLine: View {
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

/// 额度进度条下方的小刻度。
///
/// 循环会创建 13 个刻度，包含左右两端，用来把进度条视觉上分成 12 段。
struct TickMarks: Shape {
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
