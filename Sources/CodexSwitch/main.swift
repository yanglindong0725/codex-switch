import AppKit
import Foundation
import ServiceManagement
import UserNotifications

// MARK: - Menu Bar App

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let authManager = CodexAuthManager.shared
    private var fileMonitor: DispatchSourceFileSystemObject?
    private let rateLimitClient = RateLimitClient()
    private var refreshTimer: Timer?
    private var config = AppConfig.load()
    private var previousAlertState: (p5h: Bool, pWk: Bool) = (false, false)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        rateLimitClient.onUpdate = { [weak self] in self?.updateMenu() }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        authManager.syncAuthToAccounts()
        updateMenu()
        watchAuthFile()
        rateLimitClient.fetchAll(authManager.listAccounts())
        scheduleTimer()
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

    private func formatResetTime(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let mins = Int(d.timeIntervalSinceNow / 60)
        if mins <= 0 { return "现在" }
        if mins < 60 { return "\(mins)分" }
        let hours = mins / 60; let remMins = mins % 60
        if hours < 24 { return remMins > 0 ? "\(hours)小时\(remMins)分" : "\(hours)小时" }
        return "\(hours / 24)天\(hours % 24)小时"
    }

    private func makeProgressBar(remaining: Int, width: CGFloat = 100, height: CGFloat = 8) -> NSImage {
        let pct = CGFloat(min(max(remaining, 0), 100)) / 100.0
        let img = NSImage(size: NSSize(width: width, height: height))
        img.lockFocus()

        let radius: CGFloat = 4
        let trackColor = NSColor.separatorColor.withAlphaComponent(0.3)
        let bgRect = NSRect(x: 0, y: 0, width: width, height: height)
        trackColor.setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius).fill()

        let fillWidth = width * pct
        if fillWidth > 0 {
            let window = RateLimitWindow(usedPercent: 100 - remaining, resetsAt: nil)
            let fillRect = NSRect(x: 0, y: 0, width: fillWidth, height: height)
            window.barColor.setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()
        }

        img.unlockFocus()
        return img
    }

    private func barAttachment(remaining: Int) -> NSAttributedString {
        let img = makeProgressBar(remaining: remaining)
        let att = NSTextAttachment()
        att.image = img
        att.bounds = NSRect(x: 0, y: 2, width: img.size.width, height: img.size.height)
        return NSAttributedString(attachment: att)
    }

    private func sendNotification(title: String, body: String) {
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
        let others = accounts.filter { $0.alias != current }

        // Status bar - icon only, with red dot alerts
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
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.minimumWidth = 320

        // ─── Active Account ───
        if let acct = active {
            buildCard(menu, acct, isActive: true)
            menu.addItem(NSMenuItem.separator())
        }

        // ─── Other Accounts ───
        if !others.isEmpty {
            for (i, account) in others.enumerated() {
                buildCard(menu, account, isActive: false)
                if i < others.count - 1 { menu.addItem(NSMenuItem.separator()) }
            }
            menu.addItem(NSMenuItem.separator())
        }

        // ─── Actions ───
        addMenuItem(menu, "刷新全部", #selector(refreshUsage), "r")
        addMenuItem(menu, "添加账号...", #selector(addAccount), "")

        if !others.isEmpty {
            let removeItem = NSMenuItem(title: "移除账号", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for acct in others {
                let item = NSMenuItem(title: acct.alias, action: #selector(deleteAccount(_:)), keyEquivalent: "")
                item.target = self; item.representedObject = acct.alias
                sub.addItem(item)
            }
            removeItem.submenu = sub
            menu.addItem(removeItem)
        }

        menu.addItem(NSMenuItem.separator())

        let launchItem = NSMenuItem(title: "登录时启动", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        if #available(macOS 13.0, *) {
            launchItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        } else { launchItem.isEnabled = false }
        menu.addItem(launchItem)

        // Settings submenu
        let settingsItem = NSMenuItem(title: "设置", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu()

        // Auto refresh
        let refreshHeader = NSMenuItem(title: "自动刷新", action: nil, keyEquivalent: "")
        refreshHeader.isEnabled = false
        settingsMenu.addItem(refreshHeader)
        for (label, mins) in [("5 分钟", 5), ("15 分钟", 15), ("30 分钟", 30), ("1 小时", 60), ("2 小时", 120), ("关闭", 0)] {
            let opt = NSMenuItem(title: "  \(label)", action: #selector(setRefreshInterval(_:)), keyEquivalent: "")
            opt.target = self; opt.tag = mins
            opt.state = config.refreshIntervalMinutes == mins ? .on : .off
            settingsMenu.addItem(opt)
        }

        settingsMenu.addItem(NSMenuItem.separator())

        // 5h alert threshold
        let alert5hHeader = NSMenuItem(title: "5 小时额度低于", action: nil, keyEquivalent: "")
        alert5hHeader.isEnabled = false
        settingsMenu.addItem(alert5hHeader)
        for pct in [10, 20, 30, 50] {
            let opt = NSMenuItem(title: "  \(pct)%", action: #selector(setAlert5hThreshold(_:)), keyEquivalent: "")
            opt.target = self; opt.tag = pct
            opt.state = config.alert5hThreshold == pct ? .on : .off
            settingsMenu.addItem(opt)
        }

        settingsMenu.addItem(NSMenuItem.separator())

        // Week alert threshold
        let alertWkHeader = NSMenuItem(title: "每周额度低于", action: nil, keyEquivalent: "")
        alertWkHeader.isEnabled = false
        settingsMenu.addItem(alertWkHeader)
        for pct in [5, 10, 20, 30] {
            let opt = NSMenuItem(title: "  \(pct)%", action: #selector(setAlertWeekThreshold(_:)), keyEquivalent: "")
            opt.target = self; opt.tag = pct
            opt.state = config.alertWeekThreshold == pct ? .on : .off
            settingsMenu.addItem(opt)
        }

        settingsMenu.addItem(NSMenuItem.separator())

        let restartHeader = NSMenuItem(title: "切换账号后", action: nil, keyEquivalent: "")
        restartHeader.isEnabled = false
        settingsMenu.addItem(restartHeader)
        for (label, mode) in [
            ("  询问是否重启 Codex", RestartCodexAfterSwitch.ask),
            ("  自动重启 Codex", RestartCodexAfterSwitch.auto),
            ("  不处理", RestartCodexAfterSwitch.off)
        ] {
            let opt = NSMenuItem(title: label, action: #selector(setRestartCodexAfterSwitch(_:)), keyEquivalent: "")
            opt.target = self; opt.representedObject = mode.rawValue
            opt.state = config.restartCodexAfterSwitch == mode ? .on : .off
            settingsMenu.addItem(opt)
        }

        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)

        addMenuItem(menu, "退出", #selector(quit), "q")
        statusItem.menu = menu
    }

    private func addMenuItem(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    private func buildCard(_ menu: NSMenu, _ acct: CodexAccount, isActive: Bool) {
        let item = NSMenuItem()
        let s = NSMutableAttributedString()
        let indent = isActive ? "  " : "  "

        // Row 1: alias + plan
        if isActive {
            s.append(NSAttributedString(string: "\u{25CF} ", attributes: [
                .font: NSFont.systemFont(ofSize: 8), .foregroundColor: NSColor.systemGreen
            ]))
        }
        s.append(NSAttributedString(string: acct.alias, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: isActive ? .semibold : .medium),
            .foregroundColor: NSColor.labelColor
        ]))

        // Plan badge
        let badgeText = " \(acct.planLabel) "
        s.append(NSAttributedString(string: "  ", attributes: [.font: NSFont.systemFont(ofSize: 9)]))

        let badge = NSMutableAttributedString(string: badgeText, attributes: [
            .font: NSFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: acct.planColor,
            .backgroundColor: acct.planColor.withAlphaComponent(0.12),
            .baselineOffset: 2
        ])
        s.append(badge)

        // Row 2: email
        s.append(NSAttributedString(string: "\n\(indent) \(acct.email)", attributes: [
            .font: NSFont.systemFont(ofSize: 10.5),
            .foregroundColor: NSColor.secondaryLabelColor
        ]))

        // Row 3-4: usage bars
        let state = rateLimitClient.usageByAlias[acct.alias] ?? .idle
        switch state {
        case .success(let rl):
            let labelFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
            let labelColor = NSColor.tertiaryLabelColor
            let pctFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)

            if let p = rl.primary {
                s.append(NSAttributedString(string: "\n\(indent) ", attributes: [.font: NSFont.systemFont(ofSize: 11)]))
                s.append(NSAttributedString(string: "5h   ", attributes: [.font: labelFont, .foregroundColor: labelColor]))
                s.append(barAttachment(remaining: p.remaining))
                s.append(NSAttributedString(string: " ", attributes: [.font: NSFont.systemFont(ofSize: 4)]))
                let pctStr = String(format: "%3d%%", p.remaining)
                s.append(NSAttributedString(string: pctStr, attributes: [.font: pctFont, .foregroundColor: p.textColor]))
                if let r = p.resetsAt, p.remaining < 100 {
                    s.append(NSAttributedString(string: "  \(formatResetTime(r))", attributes: [
                        .font: NSFont.systemFont(ofSize: 9), .foregroundColor: labelColor]))
                }
            }
            if let sec = rl.secondary {
                s.append(NSAttributedString(string: "\n\(indent) ", attributes: [.font: NSFont.systemFont(ofSize: 11)]))
                s.append(NSAttributedString(string: "周   ", attributes: [.font: labelFont, .foregroundColor: labelColor]))
                s.append(barAttachment(remaining: sec.remaining))
                s.append(NSAttributedString(string: " ", attributes: [.font: NSFont.systemFont(ofSize: 4)]))
                let pctStr = String(format: "%3d%%", sec.remaining)
                s.append(NSAttributedString(string: pctStr, attributes: [.font: pctFont, .foregroundColor: sec.textColor]))
                if let r = sec.resetsAt, sec.remaining < 100 {
                    s.append(NSAttributedString(string: "  \(formatResetTime(r))", attributes: [
                        .font: NSFont.systemFont(ofSize: 9), .foregroundColor: labelColor]))
                }
            }

        case .loading:
            s.append(NSAttributedString(string: "\n\(indent) 加载中...", attributes: [
                .font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.tertiaryLabelColor
            ]))

        case .failed(let reason):
            s.append(NSAttributedString(string: "\n\(indent) \(reason)", attributes: [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1.0)
            ]))

        case .idle: break
        }

        item.attributedTitle = s
        if isActive {
            item.isEnabled = false
        } else {
            item.target = self; item.action = #selector(switchAccount(_:))
            item.representedObject = acct.alias
        }
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func switchAccount(_ sender: NSMenuItem) {
        guard let alias = sender.representedObject as? String else { return }
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
        config.refreshIntervalMinutes = sender.tag
        saveConfig(); scheduleTimer(); updateMenu()
    }

    @objc private func setAlert5hThreshold(_ sender: NSMenuItem) {
        config.alert5hThreshold = sender.tag
        saveConfig(); previousAlertState = (false, false); updateMenu()
    }

    @objc private func setAlertWeekThreshold(_ sender: NSMenuItem) {
        config.alertWeekThreshold = sender.tag
        saveConfig(); previousAlertState = (false, false); updateMenu()
    }

    @objc private func setRestartCodexAfterSwitch(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String,
              let mode = RestartCodexAfterSwitch(rawValue: value) else { return }
        config.restartCodexAfterSwitch = mode
        saveConfig(); updateMenu()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
                else { try SMAppService.mainApp.register() }
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

    private var lastFileEventTime: Date = .distantPast
    private var authFileMonitor: DispatchSourceFileSystemObject?

    private func onAuthChanged() {
        let now = Date()
        guard now.timeIntervalSince(lastFileEventTime) > 2 else { return }
        lastFileEventTime = now
        authManager.syncAuthToAccounts()
        updateMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            self.rateLimitClient.fetchAll(self.authManager.listAccounts())
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
let delegate = AppDelegate()
app.delegate = delegate
app.run()
