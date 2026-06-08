import Foundation
import SwiftUI

#if DEBUG
/// Canvas 预览使用的空操作。
///
/// 预览不能读写真正的 `.codex` 文件，也不能启动登录流程或退出应用。这些闭包
/// 让 Canvas 里的 UI 可以点击，但不会产生副作用。
extension SwitcherActions {
    static let preview = SwitcherActions(
        refreshUsage: {},
        addAccount: {},
        switchAccount: { _ in },
        deleteAccount: { _ in },
        setLaunchAtLogin: { _ in },
        setRefreshInterval: { _ in },
        setAlert5hThreshold: { _ in },
        setAlertWeekThreshold: { _ in },
        setRestartCodexAfterSwitch: { _ in },
        quit: {}
    )
}

/// Xcode Canvas 使用的代表性假数据。
///
/// 需要测试长账号名、加载状态、空状态或低额度颜色时，改这里即可，不需要改动
/// 本机真实账号文件。
extension SwitcherViewModel {
    static func preview() -> SwitcherViewModel {
        let model = SwitcherViewModel(actions: .preview)
        let now = Date()
        let accounts = [
            CodexAccount(
                alias: "yanglindongwe",
                email: "yanglindongwe@gmail.com",
                plan: "pro",
                authMode: "oauth",
                accountId: "preview-active",
                accessToken: "",
                subscriptionStart: nil,
                subscriptionUntil: nil,
                daysRemaining: nil,
                tokenExpiry: nil
            ),
            CodexAccount(
                alias: "liny278591",
                email: "liny27859@gmail.com",
                plan: "plus",
                authMode: "oauth",
                accountId: "preview-secondary",
                accessToken: "",
                subscriptionStart: nil,
                subscriptionUntil: nil,
                daysRemaining: nil,
                tokenExpiry: nil
            ),
            CodexAccount(
                alias: "workbench",
                email: "workbench@example.com",
                plan: "team",
                authMode: "oauth",
                accountId: "preview-team",
                accessToken: "",
                subscriptionStart: nil,
                subscriptionUntil: nil,
                daysRemaining: nil,
                tokenExpiry: nil
            )
        ]

        model.currentAlias = "yanglindongwe"
        model.accounts = accounts
        model.usageByAlias = [
            "yanglindongwe": .success(RateLimitInfo(
                primary: RateLimitWindow(usedPercent: 34, resetsAt: now.addingTimeInterval(4 * 3600 + 23 * 60)),
                secondary: RateLimitWindow(usedPercent: 24, resetsAt: now.addingTimeInterval(5 * 24 * 3600 + 21 * 3600)),
                credits: nil,
                planType: "pro"
            )),
            "liny278591": .success(RateLimitInfo(
                primary: RateLimitWindow(usedPercent: 1, resetsAt: now.addingTimeInterval(4 * 3600 + 59 * 60)),
                secondary: RateLimitWindow(usedPercent: 68, resetsAt: now.addingTimeInterval(5 * 24 * 3600 + 17 * 3600)),
                credits: nil,
                planType: "plus"
            )),
            "workbench": .loading
        ]
        model.config = AppConfig(
            refreshIntervalMinutes: 15,
            minRefreshIntervalSeconds: 60,
            alert5hThreshold: 20,
            alertWeekThreshold: 10,
            restartCodexAfterSwitch: .ask
        )
        model.launchAtLogin = true
        return model
    }
}

#Preview("Popover") {
    CodexSwitchPopoverView(model: .preview())
}
#endif
