import SwiftUI

/// 弹窗使用的固定共享色板。
///
/// 调整 UI 颜色时先从这里开始。各个视图文件会引用这些具名颜色，而不是重复
/// 写 RGB 数值；这样同一种颜色只需要改一处。
enum Palette {
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
