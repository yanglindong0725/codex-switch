import CodexSwitchPreview
import Foundation

// MARK: - Auth Manager

class CodexAuthManager {
    static let shared = CodexAuthManager()

    private let codexDir: String
    let authFile: String
    private let currentFile: String
    let accountsDir: String

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        codexDir = "\(home)/.codex"
        authFile = "\(codexDir)/auth.json"
        currentFile = "\(codexDir)/current"
        accountsDir = "\(codexDir)/accounts"
    }

    func currentAlias() -> String {
        guard let data = try? String(contentsOfFile: currentFile, encoding: .utf8) else { return "?" }
        return data.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func listAccounts() -> [CodexAccount] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: accountsDir) else { return [] }
        return files
            .filter { $0.hasSuffix(".json") }
            .sorted()
            .compactMap { file -> CodexAccount? in
                let alias = String(file.dropLast(5))
                return parseAccountFile("\(accountsDir)/\(file)", alias: alias)
            }
    }

    func switchTo(alias: String) -> Bool {
        let fm = FileManager.default
        let current = currentAlias()
        let targetFile = "\(accountsDir)/\(alias).json"
        guard fm.fileExists(atPath: targetFile) else { return false }

        if shouldSaveCurrentAuth(currentAlias: current) {
            let currentAccountFile = "\(accountsDir)/\(current).json"
            let tmpFile = currentAccountFile + ".\(UUID().uuidString).tmp"
            do {
                try fm.copyItem(atPath: authFile, toPath: tmpFile)
                try replaceFile(atPath: currentAccountFile, withItemAt: tmpFile)
            } catch { try? fm.removeItem(atPath: tmpFile) }
        }

        let switchID = UUID().uuidString
        let tmpAuthFile = "\(codexDir)/auth.switch-\(switchID).tmp"
        let tmpCurrentFile = "\(codexDir)/current.switch-\(switchID).tmp"
        do {
            try fm.copyItem(atPath: targetFile, toPath: tmpAuthFile)
            try alias.write(toFile: tmpCurrentFile, atomically: true, encoding: .utf8)
            try replaceFile(atPath: authFile, withItemAt: tmpAuthFile)
            try replaceFile(atPath: currentFile, withItemAt: tmpCurrentFile)
            return true
        } catch {
            try? fm.removeItem(atPath: tmpAuthFile)
            try? fm.removeItem(atPath: tmpCurrentFile)
            return false
        }
    }

    private func replaceFile(atPath destinationPath: String, withItemAt replacementPath: String) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destinationPath) {
            _ = try fm.replaceItemAt(URL(fileURLWithPath: destinationPath),
                                     withItemAt: URL(fileURLWithPath: replacementPath),
                                     backupItemName: nil,
                                     options: [])
        } else {
            try fm.moveItem(atPath: replacementPath, toPath: destinationPath)
        }
    }

    private func shouldSaveCurrentAuth(currentAlias: String) -> Bool {
        let fm = FileManager.default
        guard !currentAlias.isEmpty, currentAlias != "?", fm.fileExists(atPath: authFile) else { return false }
        let currentAccountFile = "\(accountsDir)/\(currentAlias).json"
        guard fm.fileExists(atPath: currentAccountFile),
              let authAccount = parseAccountFile(authFile, alias: "_auth"),
              let currentAccount = parseAccountFile(currentAccountFile, alias: currentAlias)
        else { return false }
        return authAccount.email != "?"
            && authAccount.email == currentAccount.email
            && authAccount.accountId == currentAccount.accountId
    }

    func syncAuthToAccounts() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: authFile) else { return }
        if !fm.isReadableFile(atPath: accountsDir) {
            try? fm.createDirectory(atPath: accountsDir, withIntermediateDirectories: true)
        }
        guard let authAccount = parseAccountFile(authFile, alias: "_tmp"), authAccount.email != "?" else { return }
        let accounts = listAccounts()
        if let existing = accounts.first(where: { $0.email == authAccount.email }) {
            let accountFile = "\(accountsDir)/\(existing.alias).json"
            try? fm.removeItem(atPath: accountFile)
            try? fm.copyItem(atPath: authFile, toPath: accountFile)
            try? existing.alias.write(toFile: currentFile, atomically: true, encoding: .utf8)
            return
        }
        var alias = authAccount.email.components(separatedBy: "@").first ?? "account"
        let existingAliases = Set(accounts.map { $0.alias })
        if existingAliases.contains(alias) {
            var i = 1
            while existingAliases.contains("\(alias)\(i)") { i += 1 }
            alias = "\(alias)\(i)"
        }
        try? fm.copyItem(atPath: authFile, toPath: "\(accountsDir)/\(alias).json")
        try? alias.write(toFile: currentFile, atomically: true, encoding: .utf8)
    }

    func prepareForNewLogin() throws -> String? {
        let fm = FileManager.default
        try fm.createDirectory(atPath: codexDir, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: accountsDir, withIntermediateDirectories: true)

        syncAuthToAccounts()

        guard fm.fileExists(atPath: authFile) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let baseBackupFile = "\(codexDir)/auth.switcher-backup-\(formatter.string(from: Date()))"
        var backupFile = "\(baseBackupFile).json"
        var index = 1
        while fm.fileExists(atPath: backupFile) {
            backupFile = "\(baseBackupFile)-\(index).json"
            index += 1
        }
        try fm.copyItem(atPath: authFile, toPath: backupFile)
        try fm.removeItem(atPath: authFile)
        return backupFile
    }

    func restoreAuthFromBackup(_ backupFile: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backupFile) else { return }
        if fm.fileExists(atPath: authFile) { try fm.removeItem(atPath: authFile) }
        try fm.copyItem(atPath: backupFile, toPath: authFile)
    }

    func deleteAccount(alias: String) -> Bool {
        let accountFile = "\(accountsDir)/\(alias).json"
        return (try? FileManager.default.removeItem(atPath: accountFile)) != nil
    }

    func parseAccountFile(_ path: String, alias: String) -> CodexAccount? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let authMode = json["auth_mode"] as? String ?? "chatgpt"
        let tokens = json["tokens"] as? [String: Any] ?? [:]
        let accountId = tokens["account_id"] as? String ?? "?"
        let accessToken = tokens["access_token"] as? String ?? ""
        var email = "?"; var plan = "?"
        var subStart: String?; var subUntil: String?; var daysRemaining: Int?; var tokenExpiry: Date?
        if let idToken = tokens["id_token"] as? String, let payload = decodeJWTPayload(idToken) {
            email = payload["email"] as? String ?? "?"
            if let exp = payload["exp"] as? Double { tokenExpiry = Date(timeIntervalSince1970: exp) }
            if let auth = payload["https://api.openai.com/auth"] as? [String: Any] {
                plan = auth["chatgpt_plan_type"] as? String ?? "?"
                subStart = auth["chatgpt_subscription_active_start"] as? String
                subUntil = auth["chatgpt_subscription_active_until"] as? String
                if let until = subUntil {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let d = f.date(from: until) ?? ISO8601DateFormatter().date(from: until) {
                        daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: d).day
                    }
                }
            }
        }
        if tokenExpiry == nil, let at = tokens["access_token"] as? String, let p = decodeJWTPayload(at) {
            if let exp = p["exp"] as? Double { tokenExpiry = Date(timeIntervalSince1970: exp) }
        }
        return CodexAccount(alias: alias, email: email, plan: plan, authMode: authMode,
            accountId: accountId, accessToken: accessToken,
            subscriptionStart: subStart, subscriptionUntil: subUntil,
            daysRemaining: daysRemaining, tokenExpiry: tokenExpiry)
    }

    func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let r = b64.count % 4
        if r > 0 { b64 += String(repeating: "=", count: 4 - r) }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }
}
