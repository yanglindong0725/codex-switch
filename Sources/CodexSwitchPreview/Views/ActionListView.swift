import SwiftUI

/// 账号列表下方的命令区域。
///
/// 这一层只负责命令顺序。单行高度、图标间距和快捷键文字样式由下面的
/// `ActionRow` 和 `ToggleRow` 控制。
struct ActionListView: View {
    @ObservedObject var model: SwitcherViewModel
    @Binding var showsRemoveAccounts: Bool
    @Binding var showsSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            ActionRow(icon: "arrow.clockwise", title: "刷新全部", shortcut: "⌘R") {
                model.actions.refreshUsage()
            }

            DividerLine(color: Palette.paperLine).padding(.horizontal, 18)

            ActionRow(icon: "plus.circle", title: "添加账号...", shortcut: "⌘N") {
                model.actions.addAccount()
            }

            DividerLine(color: Palette.paperLine).padding(.horizontal, 18)

            ActionRow(icon: "minus.circle", title: "移除账号", shortcut: "⌫") {
                withAnimation(.easeInOut(duration: 0.16)) { showsRemoveAccounts.toggle() }
            }

            DividerLine(color: Palette.paperLine)

            ToggleRow(model: model)

            DividerLine(color: Palette.paperLine).padding(.horizontal, 18)

            ActionRow(icon: "gearshape", title: "设置", shortcut: "⌘,") {
                withAnimation(.easeInOut(duration: 0.16)) { showsSettings.toggle() }
            }

            DividerLine(color: Palette.paperLine).padding(.horizontal, 18)

            ActionRow(icon: "power", title: "退出", shortcut: "⌘Q") {
                model.actions.quit()
            }
        }
        .background(Palette.paper)
    }
}

/// “登录时启动”开关行。
///
/// 这里使用系统开关控件，因为它表示一个持久化的二元偏好，而不是普通命令。
struct ToggleRow: View {
    @ObservedObject var model: SwitcherViewModel

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.square")
                .font(.system(size: 18, weight: .regular))
                .frame(width: 28)
            Text("登录时启动")
                .font(.system(size: 16, weight: .regular))
            Spacer()
            Toggle("", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.actions.setLaunchAtLogin($0) }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle())
            .accentColor(Color(red: 0.18, green: 0.68, blue: 0.28))
        }
        .foregroundColor(Palette.ink)
        .padding(.horizontal, 18)
        .frame(height: 44)
    }
}

/// 可复用的“图标 + 标题 + 快捷键”命令行。
///
/// 修改 `.frame(height: 36)` 可以让所有命令行更紧凑或更宽松。图标固定宽度是为了
/// 让不同 SF Symbols 宽度不一致时，文字仍然对齐。
struct ActionRow: View {
    let icon: String
    let title: String
    let shortcut: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                Spacer()
                Text(shortcut)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Palette.ink.opacity(0.55))
            }
            .foregroundColor(Palette.ink)
            .padding(.horizontal, 18)
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 内联的危险操作账号移除面板。
///
/// 它会在用户点击“移除账号”后才显示，避免危险操作长期暴露在紧凑弹窗里。
struct RemoveAccountsView: View {
    @ObservedObject var model: SwitcherViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.otherAccounts, id: \.alias) { account in
                Button {
                    model.actions.deleteAccount(account.alias)
                } label: {
                    HStack {
                        Text("移除 \(account.alias)")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: "trash")
                    }
                    .foregroundColor(.red.opacity(0.88))
                    .padding(.horizontal, 22)
                    .frame(height: 34)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(red: 0.99, green: 0.96, blue: 0.94))
        .overlay(DividerLine(color: Palette.paperLine), alignment: .top)
    }
}
