import SwiftUI

/// 深色区和浅色区共用的一像素分隔线。
///
/// 单独封装成视图，是为了避免每个分区里重复写
/// `Rectangle().frame(height: 1)`，让布局代码更好读。
struct DividerLine: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

/// 用于弹窗展示的邮箱脱敏函数。
///
/// 例如 `person@example.com` 会显示为 `p***@example.com`。这样既节省空间，
/// 又能让用户分辨不同账号。
func maskEmail(_ email: String) -> String {
    guard email != "?", let atIndex = email.firstIndex(of: "@") else { return email }
    let name = String(email[..<atIndex])
    let domain = String(email[atIndex...])
    let first = name.first.map(String.init) ?? "?"
    return "\(first)***\(domain)"
}
