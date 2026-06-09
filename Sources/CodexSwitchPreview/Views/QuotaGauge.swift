import SwiftUI  // 引入 SwiftUI，提供 View、Text、HStack、Shape 等界面类型。

/// 当前账号深色区域里使用的完整额度条。
///
/// 固定的 `barWidth` 和右侧重置时间宽度用于保持两条额度行对齐。如果弹窗宽度变化，
/// 优先从这里重新平衡布局。
struct QuotaGauge: View {  // 定义当前账号区域使用的完整额度条组件。
    let label: String  // 左侧显示的额度类型标签，例如 5h 或周。
    let metric: QuotaMetric  // 当前额度条需要展示的格式化数据和进度比例。

    var body: some View {  // 声明 SwiftUI 组件的界面内容。
        let barWidth: CGFloat = 196  // 固定进度条宽度，保证两条额度行视觉对齐。

        HStack(alignment: .center, spacing: 10) {  // 横向排列标签、进度条和重置时间。
            Text(label)  // 渲染左侧额度类型标签。
                .font(.system(size: 19, weight: .regular))  // 设置标签字号和字重。
                .frame(width: 42, alignment: .leading)  // 固定标签列宽，避免不同文案影响后续布局。

            VStack(spacing: 6) {  // 纵向排列进度条标题、进度条本体和刻度文字。
                HStack {  // 顶部一行展示说明文案和剩余百分比。
                    Text("剩余额度")  // 显示进度条左侧说明文案。
                        .font(.system(size: 12, weight: .regular))  // 设置说明文案字号和字重。
                        .foregroundColor(.white.opacity(0.78))  // 使用半透明白色降低说明文案权重。
                    Spacer()  // 推开左右文本，让百分比靠右。
                    Text(metric.remainingPercentText)  // 显示格式化后的剩余额度百分比。
                        .font(.system(size: 12, weight: .semibold))  // 让百分比比说明文案更醒目。
                        .foregroundColor(Palette.mutedGreen)  // 使用绿色强调剩余额度。
                }  // 结束顶部说明行。

                ZStack(alignment: .leading) {  // 叠放轨道、绿色进度和白色当前位置指示器。
                    Capsule().fill(Palette.track)  // 绘制完整的深色背景轨道。
                    Capsule().fill(Palette.green).frame(width: barWidth * metric.fraction)  // 按剩余比例绘制绿色进度。
                    Rectangle()  // 绘制当前进度末端的白色指示条。
                        .fill(Color.white)  // 设置指示条为白色。
                        .frame(width: 3, height: 6)  // 设置指示条宽高。
                        .cornerRadius(1.5)  // 给指示条轻微圆角。
                        .offset(x: max(0, barWidth * metric.fraction - 2))  // 把指示条移动到当前进度末端。
                }  // 结束进度条叠层。
                .frame(width: barWidth, height: 6)  // 设置进度条整体宽高。
                .border(Color.white.opacity(0.3), width: 0.2)  // 给指示条添加半透明白色边框，增加视觉层次。
                .cornerRadius(5)
                .padding(.bottom, 8)  // 给进度条上下添加一些垂直间距。

                HStack(spacing: 0) {  // 横向排列进度条下方的三个刻度标签。
                    Text("0%")  // 左侧刻度标签。
                    Spacer()  // 将中间刻度推到中间位置。
                    Text(metric.middleLabel)  // 中间刻度标签，通常是 50%。
                    Spacer()  // 将右侧刻度推到末端。
                    Text("100%")  // 右侧刻度标签。
                }  // 结束刻度标签行。
                .font(.system(size: 11, weight: .regular))  // 设置刻度标签字号。
                .foregroundColor(.white.opacity(0.78))  // 设置刻度标签颜色。
                .overlay(  // 在刻度标签上方叠加细刻度线。
                    TickMarks()  // 创建自定义刻度线形状。
                        .stroke(Color.white.opacity(0.8), lineWidth: 0.4)  // 设置刻度线颜色和线宽。
                        .frame(height: 6)  // 设置刻度线高度。
                        .offset(y: -12)  // 将刻度线向上移动到进度条下方。
                )  // 结束刻度线叠加。
            }  // 结束进度条中间列。
            .frame(width: barWidth)  // 固定中间列宽度，与进度条宽度一致。

            HStack(alignment: .top, spacing: 7) {  // 横向排列时钟图标和重置时间文本。
                Image(systemName: "clock")  // 显示系统时钟图标。
                    .font(.system(size: 13, weight: .regular))  // 设置时钟图标大小和字重。
                    .foregroundColor(.white.opacity(0.72))  // 设置图标为半透明白色。
                    .padding(.top, 2)  // 微调图标垂直位置，使其对齐文字。

                VStack(alignment: .leading, spacing: 3) {  // 纵向排列重置标题和具体时间。
                    Text(metric.resetTitle)  // 显示重置时间的标题。
                    Text(metric.resetValue)  // 显示格式化后的重置时间值。
                }  // 结束重置时间文本列。
                .font(.system(size: 11, weight: .regular))  // 设置重置时间文本字号。
                .foregroundColor(.white.opacity(0.72))  // 设置重置时间文本颜色。
            }  // 结束右侧重置时间区域。
            .frame(width: 124, alignment: .leading)  // 固定右侧列宽，保证两条额度行对齐。
        }  // 结束完整额度条横向布局。
    }  // 结束 QuotaGauge 的 body。
}  // 结束 QuotaGauge 组件定义。

/// 非当前账号行里使用的紧凑两列额度文本。
struct CompactQuotaLine: View {  // 定义账号列表行里使用的紧凑额度文本组件。
    let label: String  // 左侧额度类型标签，例如 5h 或周。
    let metric: QuotaMetric  // 当前额度文本需要展示的格式化数据。

    var body: some View {  // 声明紧凑额度文本的界面内容。
        HStack(spacing: 8) {  // 横向排列类型标签和剩余额度文本。
            Text(label)  // 渲染额度类型标签。
                .font(.system(size: 14, weight: .medium))  // 设置标签字号和字重。
                .frame(width: 20, alignment: .leading)  // 固定标签宽度，让两行文字对齐。
            Text(metric.remainingValueText)  // 显示格式化后的剩余额度文本。
                .font(.system(size: 15, weight: .regular))  // 设置剩余额度文本字号。
                .foregroundColor(Palette.mutedInk)  // 使用弱化文字颜色降低视觉权重。
        }  // 结束紧凑额度横向布局。
    }  // 结束 CompactQuotaLine 的 body。
}  // 结束 CompactQuotaLine 组件定义。

/// 额度进度条下方的小刻度。
///
/// 循环会创建 13 个刻度，包含左右两端，用来把进度条视觉上分成 12 段。
struct TickMarks: Shape {  // 定义进度条下方刻度线的自定义形状。
    func path(in rect: CGRect) -> Path {  // 根据给定绘制区域生成刻度线路径。
        var path = Path()  // 创建可变路径，用来逐条添加刻度线。
        for index in 0...12 {  // 循环生成 13 条刻度线，覆盖 0 到 12 个分段点。
            let x = rect.minX + rect.width * CGFloat(index) / 12  // 计算当前刻度线的横向位置。
            path.move(to: CGPoint(x: x, y: rect.minY))  // 将路径起点移动到当前刻度线顶部。
            path.addLine(to: CGPoint(x: x, y: rect.maxY))  // 从顶部向底部画出当前刻度线。
        }  // 结束刻度线循环。
        return path  // 返回完整刻度线路径给 SwiftUI 绘制。
    }  // 结束 path(in:) 实现。
}  // 结束 TickMarks 形状定义。
