import SwiftUI

/// 菜单栏图标点开后显示的弹窗根视图。
///
/// 这个文件应该保持轻量：只负责组合主要区域，并持有“移除账号”和“设置”
/// 两个展开状态。调整具体视觉时，优先修改 `Views/` 下的分区文件，以及
/// `Support/PopoverPalette.swift` 里的共享颜色。
public struct CodexSwitchPopoverView: View {
    @ObservedObject var model: SwitcherViewModel
    @State private var showsSettings = false
    @State private var showsRemoveAccounts = false
    @State private var pendingSwitchAlias: String?

    public init(model: SwitcherViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            if let active = model.activeAccount {
                ActiveAccountView(
                    account: active,
                    state: model.usageByAlias[active.alias] ?? .idle
                )
            } else {
                EmptyActiveAccountView()
            }

            AccountListView(model: model, pendingSwitchAlias: $pendingSwitchAlias)

            ActionListView(
                model: model,
                showsRemoveAccounts: $showsRemoveAccounts,
                showsSettings: $showsSettings
            )

            if showsRemoveAccounts {
                RemoveAccountsView(model: model)
            }

            if showsSettings {
                SettingsView(model: model)
            }
        }
        .frame(width: 430)
        .background(Palette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.36), radius: 28, x: 0, y: 18)
    }
}
