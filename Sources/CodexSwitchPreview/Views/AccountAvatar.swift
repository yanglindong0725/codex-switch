import SwiftUI

/// 当前账号和非当前账号行共用的圆形头像。
///
/// `size` 控制主圆尺寸。外层 frame 是 `size + 2`，这样右下角状态点可以略微
/// 超出圆形边缘，同时不会被裁掉。
struct AccountAvatar: View {
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
