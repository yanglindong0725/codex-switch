import AppKit
import CodexSwitchCore
import CodexSwitchPreview
import Foundation
import ServiceManagement
import SwiftUI
import UserNotifications

// MARK: - Menu Bar App

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel: SwitcherViewModel!
    private let authManager = CodexAuthManager.shared
    private var fileMonitor: DispatchSourceFileSystemObject?
    private let rateLimitClient = RateLimitClient()
    private var refreshTimer: Timer?
    private var authChangeWorkItem: DispatchWorkItem?
    private var loginPollTimer: Timer?
    private var loginPollingDeadline: Date?
    private var config = AppConfig.load()
    private var previousAlertState: (p5h: Bool, pWk: Bool) = (false, false)
    private var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        viewModel = SwitcherViewModel(actions: makeActions())
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 430, height: 720)
        popover.contentViewController = NSHostingController(rootView: CodexSwitchPopoverView(model: viewModel))
        rateLimitClient.onUpdate = { [weak self] in self?.updateMenu() }
        if canUseUserNotifications {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        syncCurrentAuth(showErrors: true)
        updateMenu()
        watchAuthFile()
        rateLimitClient.fetchAll(authManager.listAccounts())
        scheduleTimer()
    }

    private func makeActions() -> SwitcherActions {
        SwitcherActions(
            refreshUsage: { [weak self] in self?.refreshUsage() },
            addAccount: { [weak self] in self?.addAccount() },
            switchAccount: { [weak self] alias in self?.switchAccount(alias: alias) },
            deleteAccount: { [weak self] alias in self?.deleteAccount(alias: alias) },
            setLaunchAtLogin: { [weak self] enabled in self?.setLaunchAtLogin(enabled) },
            setRefreshInterval: { [weak self] minutes in self?.setRefreshInterval(minutes) },
            setAlert5hThreshold: { [weak self] threshold in self?.setAlert5hThreshold(threshold) },
            setAlertWeekThreshold: { [weak self] threshold in self?.setAlertWeekThreshold(threshold) },
            setRestartCodexAfterSwitch: { [weak self] mode in self?.setRestartCodexAfterSwitch(mode) },
            quit: { NSApplication.shared.terminate(nil) }
        )
    }

    private func scheduleTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        guard config.refreshIntervalMinutes > 0 else { return }
        let interval = TimeInterval(config.refreshIntervalMinutes * 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.rateLimitClient.fetchAll(self.authManager.listAccounts())
        }
    }

    // Refresh on menu open (smart: skip if recent)
    func menuWillOpen(_ menu: NSMenu) {
        let minInterval = TimeInterval(config.minRefreshIntervalSeconds)
        rateLimitClient.refreshIfNeeded(authManager.listAccounts(), minInterval: minInterval)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            let minInterval = TimeInterval(config.minRefreshIntervalSeconds)
            rateLimitClient.refreshIfNeeded(authManager.listAccounts(), minInterval: minInterval)
            updateMenu()
            let popoverMenuBarInset: CGFloat = 8
            let anchorRect = button.bounds.offsetBy(dx: 0, dy: popoverMenuBarInset)
            popover.show(relativeTo: anchorRect, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Drawing Helpers

    private func makeStatusIcon(state: Int) -> NSImage {
        // state: 0 = normal, 1 = 5h alert, 2 = weekly alert
        let s: CGFloat = 18
        let img = NSImage(size: NSSize(width: s, height: s))
        img.lockFocus()
        if let icon = NSImage(named: "AppIcon") ?? NSImage(named: "AppIcon.icns") {
            icon.draw(in: NSRect(x: 0, y: 0, width: s, height: s),
                      from: .zero,
                      operation: .sourceOver,
                      fraction: 1.0)
        } else {
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: s - 4, height: s - 4)).fill()
        }

        if state > 0 {
            let dotSize: CGFloat = 6
            let dotRect = NSRect(x: s - dotSize, y: s - dotSize, width: dotSize, height: dotSize)
            NSColor.windowBackgroundColor.setFill()
            NSBezierPath(ovalIn: dotRect.insetBy(dx: -1, dy: -1)).fill()
            (state == 2 ? NSColor.systemRed : NSColor.systemOrange).setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        }

        img.unlockFocus()
        img.isTemplate = false
        return img
    }

    private func sendNotification(title: String, body: String) {
        guard canUseUserNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // MARK: - Build Menu

    private func updateMenu() {
        let current = authManager.currentAlias()
        let accounts = authManager.listAccounts()
        let active = accounts.first(where: { $0.alias == current })

        viewModel?.update(currentAlias: current, accounts: accounts, usageByAlias: rateLimitClient.usageByAlias, config: config)

        if let button = statusItem.button {
            var alert5h = false, alertWk = false
            if let acct = active, case .success(let rl) = rateLimitClient.usageByAlias[acct.alias] {
                let p5h = rl.primary?.remaining ?? 100
                let pWk = rl.secondary?.remaining ?? 100
                alert5h = p5h < config.alert5hThreshold
                alertWk = pWk < config.alertWeekThreshold

                // Send notification on new alerts (not on every refresh)
                if alert5h && !previousAlertState.p5h {
                    sendNotification(title: "\(acct.alias) - 5h 额度不足",
                        body: "5h 剩余：\(p5h)%")
                }
                if alertWk && !previousAlertState.pWk {
                    sendNotification(title: "\(acct.alias) - 每周额度不足",
                        body: "每周剩余：\(pWk)%")
                }
                previousAlertState = (alert5h, alertWk)

                button.toolTip = "Codex: \(acct.alias) | 5h: \(p5h)% | 周: \(pWk)%"
            } else {
                button.toolTip = "Codex: \(active?.alias ?? current)"
            }
            let iconState = alertWk ? 2 : (alert5h ? 1 : 0)
            button.image = makeStatusIcon(state: iconState)
            button.title = ""
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        statusItem.menu = nil
    }

    // MARK: - Actions

    @objc private func switchAccount(_ sender: NSMenuItem) {
        guard let alias = sender.representedObject as? String else { return }
        switchAccount(alias: alias)
    }

    private func switchAccount(alias: String) {
        if authManager.switchTo(alias: alias) {
            updateMenu()
            // Refresh in background after a delay, don't block UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self = self else { return }
                self.rateLimitClient.fetchAll(self.authManager.listAccounts())
            }
            sendNotification(title: "Codex 账号已切换", body: "当前使用：\(alias)")
            handleCodexDesktopRefreshAfterSwitch()
        } else {
            let a = NSAlert(); a.messageText = "切换失败"
            a.informativeText = "无法切换到“\(alias)”"; a.alertStyle = .warning; a.runModal()
        }
    }

    private func handleCodexDesktopRefreshAfterSwitch() {
        switch config.restartCodexAfterSwitch {
        case .off:
            return
        case .auto:
            restartCodexDesktopIfRunning()
        case .ask:
            guard isCodexDesktopRunning() else { return }
            let alert = NSAlert()
            alert.messageText = "重启 Codex 桌面端？"
            alert.informativeText = "重启 Codex 桌面端以应用账号切换。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "立即重启")
            alert.addButton(withTitle: "稍后")
            if alert.runModal() == .alertFirstButtonReturn {
                restartCodexDesktopIfRunning()
            }
        }
    }

    private func isCodexDesktopRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex").isEmpty
    }

    private func restartCodexDesktopIfRunning() {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")
        guard !apps.isEmpty else { return }

        for app in apps { app.terminate() }

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if !isCodexDesktopRunning() { break }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }

        guard !isCodexDesktopRunning() else {
            showCodexRestartError("Codex 桌面端没有退出。请手动重启 Codex 以应用账号切换。")
            return
        }

        let appURL = URL(fileURLWithPath: "/Applications/Codex.app")
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            showCodexRestartError("找不到 /Applications/Codex.app。请手动打开 Codex。")
            return
        }

        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.showCodexRestartError("无法重新打开 Codex 桌面端：\(error.localizedDescription)")
                }
            }
        }
    }

    private func showCodexRestartError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "无法重启 Codex"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func showConfigSaveError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "无法保存设置"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func saveConfig() {
        do {
            try config.save()
        } catch {
            showConfigSaveError(error)
        }
    }

    @objc private func deleteAccount(_ sender: NSMenuItem) {
        guard let alias = sender.representedObject as? String else { return }
        deleteAccount(alias: alias)
    }

    private func deleteAccount(alias: String) {
        if alias == authManager.currentAlias() {
            let a = NSAlert(); a.messageText = "无法移除当前账号"
            a.informativeText = "请先切换到其他账号。"; a.alertStyle = .warning; a.runModal()
            return
        }
        let c = NSAlert(); c.messageText = "移除“\(alias)”？"
        c.informativeText = "之后可以通过登录重新添加。"
        c.alertStyle = .warning; c.addButton(withTitle: "移除"); c.addButton(withTitle: "取消")
        if c.runModal() == .alertFirstButtonReturn {
            if authManager.deleteAccount(alias: alias) {
                rateLimitClient.usageByAlias.removeValue(forKey: alias); updateMenu()
            }
        }
    }

    @objc private func refreshUsage() {
        rateLimitClient.fetchAll(authManager.listAccounts())
    }

    @objc private func addAccount() {
        let confirm = NSAlert()
        confirm.messageText = "添加 Codex 账号"
        confirm.informativeText = "Codex Switch 会保存当前账号，临时移走 auth.json，然后打开终端运行 codex login。不要使用 codex logout。"
        confirm.alertStyle = .informational
        confirm.addButton(withTitle: "开始登录")
        confirm.addButton(withTitle: "取消")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        var backupFile: String?
        do {
            backupFile = try authManager.prepareForNewLogin()
            updateMenu()
            try openCodexLoginTerminal(backupFile: backupFile)
            startLoginCompletionPolling()
        } catch {
            let restoreMessage: String
            if let backupFile = backupFile {
                do {
                    try authManager.restoreAuthFromBackup(backupFile)
                    restoreMessage = "\n\n已恢复之前的 auth.json。"
                    updateMenu()
                } catch {
                    restoreMessage = "\n\n无法自动恢复 auth.json。备份位置：\(backupFile)"
                }
            } else {
                restoreMessage = ""
            }

            let alert = NSAlert()
            alert.messageText = "无法启动登录"
            alert.informativeText = error.localizedDescription + restoreMessage
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func openCodexLoginTerminal(backupFile: String?) throws {
        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codex-switcher-login.command")
        let backupLine = backupFile.map {
            "echo \(shellQuoted("之前的 auth.json 备份：\($0)"))"
        } ?? "echo '未找到现有 auth.json。'"
        let script = """
        #!/bin/zsh
        clear
        echo 'Codex Switch - 添加账号'
        echo
        echo '此流程不会运行 codex logout。'
        \(backupLine)
        echo
        echo '正在启动 codex login...'
        echo
        codex login
        echo
        echo '登录完成后，Codex Switch 会自动检测新的 auth.json。'
        echo '你可以关闭此窗口。'
        read -k 1 '?按任意键关闭...'
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        if !NSWorkspace.shared.open(scriptURL) {
            throw NSError(domain: "Codex Switch", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "无法打开终端运行 codex login。"
            ])
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    @objc private func setRefreshInterval(_ sender: NSMenuItem) {
        setRefreshInterval(sender.tag)
    }

    private func setRefreshInterval(_ minutes: Int) {
        config.refreshIntervalMinutes = minutes
        saveConfig(); scheduleTimer(); updateMenu()
    }

    @objc private func setAlert5hThreshold(_ sender: NSMenuItem) {
        setAlert5hThreshold(sender.tag)
    }

    private func setAlert5hThreshold(_ threshold: Int) {
        config.alert5hThreshold = threshold
        saveConfig(); previousAlertState = (false, false); updateMenu()
    }

    @objc private func setAlertWeekThreshold(_ sender: NSMenuItem) {
        setAlertWeekThreshold(sender.tag)
    }

    private func setAlertWeekThreshold(_ threshold: Int) {
        config.alertWeekThreshold = threshold
        saveConfig(); previousAlertState = (false, false); updateMenu()
    }

    @objc private func setRestartCodexAfterSwitch(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String,
              let mode = RestartCodexAfterSwitch(rawValue: value) else { return }
        setRestartCodexAfterSwitch(mode)
    }

    private func setRestartCodexAfterSwitch(_ mode: RestartCodexAfterSwitch) {
        config.restartCodexAfterSwitch = mode
        saveConfig(); updateMenu()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            setLaunchAtLogin(SMAppService.mainApp.status != .enabled)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
                updateMenu()
            } catch {
                let alert = NSAlert()
                alert.messageText = "无法更新登录项"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }

    private var authFileMonitor: DispatchSourceFileSystemObject?

    private func onAuthChanged() {
        authChangeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.syncCurrentAuth(showErrors: false)
        }
        authChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    @discardableResult
    private func syncCurrentAuth(showErrors: Bool) -> AuthSyncResult {
        do {
            let result = try authManager.syncAuthToAccounts()
            updateMenu()
            if result == .invalidAuth && showErrors {
                showAuthSyncError("auth.json 缺少有效的 email 或 account_id。")
            }
            if case .saved = result {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self = self else { return }
                    self.rateLimitClient.fetchAll(self.authManager.listAccounts())
                }
            }
            return result
        } catch {
            updateMenu()
            if showErrors {
                showAuthSyncError(error.localizedDescription)
            }
            return .invalidAuth
        }
    }

    private func showAuthSyncError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "无法同步 Codex 账号"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func startLoginCompletionPolling() {
        loginPollTimer?.invalidate()
        loginPollingDeadline = Date().addingTimeInterval(120)
        loginPollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if let deadline = self.loginPollingDeadline, Date() > deadline {
                timer.invalidate()
                self.loginPollTimer = nil
                self.loginPollingDeadline = nil
                return
            }
            if case .saved = self.syncCurrentAuth(showErrors: false) {
                timer.invalidate()
                self.loginPollTimer = nil
                self.loginPollingDeadline = nil
            }
        }
    }

    private func watchAuthFile() {
        let codexDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")

        // Watch directory (catches new files, renames)
        let dirFd = open(codexDir.path, O_EVTONLY)
        if dirFd >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: dirFd, eventMask: [.write, .rename], queue: .main)
            source.setEventHandler { [weak self] in
                self?.onAuthChanged()
                // Re-watch auth.json in case it was recreated
                self?.watchAuthJsonFile()
            }
            source.setCancelHandler { close(dirFd) }
            source.resume()
            fileMonitor = source
        }

        watchAuthJsonFile()
    }

    private func watchAuthJsonFile() {
        // Cancel previous watcher
        authFileMonitor?.cancel()
        authFileMonitor = nil

        let authPath = authManager.authFile
        let authFd = open(authPath, O_EVTONLY)
        guard authFd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: authFd, eventMask: [.write, .rename, .delete, .attrib], queue: .main)
        source.setEventHandler { [weak self] in
            self?.onAuthChanged()
            // File may have been replaced, re-watch
            self?.watchAuthJsonFile()
        }
        source.setCancelHandler { close(authFd) }
        source.resume()
        authFileMonitor = source
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let instanceLock = CodexSwitchInstanceLock()
do {
    guard try instanceLock.acquire() else {
        let alert = NSAlert()
        alert.messageText = "Codex Switch 已在运行"
        alert.informativeText = "请使用已经打开的菜单栏实例，避免多个实例同时写入账号文件。"
        alert.alertStyle = .informational
        alert.runModal()
        exit(0)
    }
} catch {
    let alert = NSAlert()
    alert.messageText = "无法启动 Codex Switch"
    alert.informativeText = "无法创建单实例锁：\(error.localizedDescription)"
    alert.alertStyle = .warning
    alert.runModal()
    exit(1)
}
let delegate = AppDelegate()
app.delegate = delegate
app.run()
