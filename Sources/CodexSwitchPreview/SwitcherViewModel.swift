import AppKit
import Foundation
import ServiceManagement

public struct SwitcherActions {
    public let refreshUsage: () -> Void
    public let addAccount: () -> Void
    public let switchAccount: (String) -> Void
    public let deleteAccount: (String) -> Void
    public let setLaunchAtLogin: (Bool) -> Void
    public let setRefreshInterval: (Int) -> Void
    public let setAlert5hThreshold: (Int) -> Void
    public let setAlertWeekThreshold: (Int) -> Void
    public let setRestartCodexAfterSwitch: (RestartCodexAfterSwitch) -> Void
    public let quit: () -> Void

    public init(
        refreshUsage: @escaping () -> Void,
        addAccount: @escaping () -> Void,
        switchAccount: @escaping (String) -> Void,
        deleteAccount: @escaping (String) -> Void,
        setLaunchAtLogin: @escaping (Bool) -> Void,
        setRefreshInterval: @escaping (Int) -> Void,
        setAlert5hThreshold: @escaping (Int) -> Void,
        setAlertWeekThreshold: @escaping (Int) -> Void,
        setRestartCodexAfterSwitch: @escaping (RestartCodexAfterSwitch) -> Void,
        quit: @escaping () -> Void
    ) {
        self.refreshUsage = refreshUsage
        self.addAccount = addAccount
        self.switchAccount = switchAccount
        self.deleteAccount = deleteAccount
        self.setLaunchAtLogin = setLaunchAtLogin
        self.setRefreshInterval = setRefreshInterval
        self.setAlert5hThreshold = setAlert5hThreshold
        self.setAlertWeekThreshold = setAlertWeekThreshold
        self.setRestartCodexAfterSwitch = setRestartCodexAfterSwitch
        self.quit = quit
    }
}

public final class SwitcherViewModel: ObservableObject {
    @Published public var currentAlias: String = "?"
    @Published public var accounts: [CodexAccount] = []
    @Published public var usageByAlias: [String: FetchState] = [:]
    @Published public var config = AppConfig()
    @Published public var launchAtLogin = false
    @Published public var isRefreshing = false

    public let actions: SwitcherActions

    public init(actions: SwitcherActions) {
        self.actions = actions
    }

    public var activeAccount: CodexAccount? {
        accounts.first { $0.alias == currentAlias }
    }

    public var otherAccounts: [CodexAccount] {
        accounts.filter { $0.alias != currentAlias }
    }

    public func update(currentAlias: String, accounts: [CodexAccount], usageByAlias: [String: FetchState], config: AppConfig) {
        self.currentAlias = currentAlias
        self.accounts = accounts
        self.usageByAlias = usageByAlias
        self.config = config
        self.isRefreshing = usageByAlias.values.contains { state in
            if case .loading = state { return true }
            return false
        }
        if #available(macOS 13.0, *) {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        } else {
            self.launchAtLogin = false
        }
    }
}
