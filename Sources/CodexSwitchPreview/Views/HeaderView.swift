import SwiftUI

/// 弹窗顶部标题栏。
///
/// 想调整应用标题字号、在线状态胶囊、右侧图标或顶部深色渐变高度时，主要改这里。
struct HeaderView: View {
    private var versionLabel: String? {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return "v\(version)"
    }

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 9) {
                Text("Codex Switch")
                    .font(.system(size: 20, weight: .regular, design: .default))
                    .foregroundColor(.white)

                if let versionLabel {
                    Text(versionLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.72))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(Palette.green)
                    .frame(width: 8, height: 8)
                Text("在线")
                    .font(.system(size: 14, weight: .regular))
            }
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 17)
        .background(
            LinearGradient(colors: [Palette.panelTop, Palette.panelBottom], startPoint: .top, endPoint: .bottom)
        )
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
