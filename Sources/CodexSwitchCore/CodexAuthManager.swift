import Foundation

public enum AuthSyncResult: Equatable {
    case noAuth
    case invalidAuth
    case saved(alias: String)
}

public enum CodexAuthManagerError: LocalizedError, Equatable {
    case invalidAuth
    case accountWriteVerificationFailed(alias: String)

    public var errorDescription: String? {
        switch self {
        case .invalidAuth:
            return "auth.json 缺少有效的 email 或 account_id。"
        case .accountWriteVerificationFailed(let alias):
            return "账号“\(alias)”写入后校验失败。"
        }
    }
}

public final class CodexAuthManager {
    public static let shared = CodexAuthManager()

    private let codexDir: String
    public let authFile: String
    private let currentFile: String
    public let accountsDir: String

    public init(codexDir: String? = nil) {
        let resolvedCodexDir = codexDir ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.codex"
        self.codexDir = resolvedCodexDir
        authFile = "\(resolvedCodexDir)/auth.json"
        currentFile = "\(resolvedCodexDir)/current"
        accountsDir = "\(resolvedCodexDir)/accounts"
    }

    public func currentAlias() -> String {
        guard let data = try? String(contentsOfFile: currentFile, encoding: .utf8) else { return "?" }
        return data.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func listAccounts() -> [CodexAccount] {
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

    public func switchTo(alias: String) -> Bool {
        let fm = FileManager.default
        let current = currentAlias()
        let targetFile = "\(accountsDir)/\(alias).json"
        guard fm.fileExists(atPath: targetFile) else { return false }

        if shouldSaveCurrentAuth(currentAlias: current) {
            do {
                try copyAuthFileAtomically(to: "\(accountsDir)/\(current).json")
            } catch {
                return false
            }
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

    public func syncAuthToAccounts() throws -> AuthSyncResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: authFile) else { return .noAuth }
        try fm.createDirectory(atPath: accountsDir, withIntermediateDirectories: true)
        guard let authAccount = parseAccountFile(authFile, alias: "_auth") else { return .invalidAuth }
        guard hasValidIdentity(authAccount) else { return .invalidAuth }

        let accounts = listAccounts()
        let alias = accounts.first(where: { isSameIdentity($0, authAccount) })?.alias
            ?? makeUniqueAlias(for: authAccount, existingAliases: Set(accounts.map(\.alias)))
        let accountFile = "\(accountsDir)/\(alias).json"

        try copyAuthFileAtomically(to: accountFile)
        guard let savedAccount = parseAccountFile(accountFile, alias: alias),
              isSameIdentity(savedAccount, authAccount)
        else {
            throw CodexAuthManagerError.accountWriteVerificationFailed(alias: alias)
        }

        try writeCurrentAlias(alias)
        return .saved(alias: alias)
    }

    public func prepareForNewLogin() throws -> String? {
        let fm = FileManager.default
        try fm.createDirectory(atPath: codexDir, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: accountsDir, withIntermediateDirectories: true)

        switch try syncAuthToAccounts() {
        case .saved, .noAuth:
            break
        case .invalidAuth:
            throw CodexAuthManagerError.invalidAuth
        }

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

    public func restoreAuthFromBackup(_ backupFile: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backupFile) else { return }
        try copyFileAtomically(from: backupFile, to: authFile)
    }

    public func deleteAccount(alias: String) -> Bool {
        let accountFile = "\(accountsDir)/\(alias).json"
        return (try? FileManager.default.removeItem(atPath: accountFile)) != nil
    }

    public func parseAccountFile(_ path: String, alias: String) -> CodexAccount? {
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

    public func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let r = b64.count % 4
        if r > 0 { b64 += String(repeating: "=", count: 4 - r) }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    private func shouldSaveCurrentAuth(currentAlias: String) -> Bool {
        let fm = FileManager.default
        guard !currentAlias.isEmpty, currentAlias != "?", fm.fileExists(atPath: authFile) else { return false }
        let currentAccountFile = "\(accountsDir)/\(currentAlias).json"
        guard fm.fileExists(atPath: currentAccountFile),
              let authAccount = parseAccountFile(authFile, alias: "_auth"),
              let currentAccount = parseAccountFile(currentAccountFile, alias: currentAlias)
        else { return false }
        return hasValidIdentity(authAccount) && isSameIdentity(authAccount, currentAccount)
    }

    private func hasValidIdentity(_ account: CodexAccount) -> Bool {
        !account.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && account.email != "?"
            && !account.accountId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && account.accountId != "?"
    }

    private func isSameIdentity(_ lhs: CodexAccount, _ rhs: CodexAccount) -> Bool {
        lhs.email == rhs.email && lhs.accountId == rhs.accountId
    }

    private func makeUniqueAlias(for account: CodexAccount, existingAliases: Set<String>) -> String {
        let base = safeAliasBase(from: account.email)
        guard existingAliases.contains(base) else { return base }
        var index = 1
        while existingAliases.contains("\(base)\(index)") { index += 1 }
        return "\(base)\(index)"
    }

    private func safeAliasBase(from email: String) -> String {
        let local = email.components(separatedBy: "@").first ?? "account"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let scalars = local.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let alias = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: ".-_"))
        return alias.isEmpty ? "account" : alias
    }

    private func copyAuthFileAtomically(to destinationPath: String) throws {
        try copyFileAtomically(from: authFile, to: destinationPath)
    }

    private func copyFileAtomically(from sourcePath: String, to destinationPath: String) throws {
        let fm = FileManager.default
        let tmpFile = "\(destinationPath).\(UUID().uuidString).tmp"
        do {
            try fm.copyItem(atPath: sourcePath, toPath: tmpFile)
            try replaceFile(atPath: destinationPath, withItemAt: tmpFile)
        } catch {
            try? fm.removeItem(atPath: tmpFile)
            throw error
        }
    }

    private func writeCurrentAlias(_ alias: String) throws {
        let tmpCurrentFile = "\(currentFile).\(UUID().uuidString).tmp"
        do {
            try alias.write(toFile: tmpCurrentFile, atomically: true, encoding: .utf8)
            try replaceFile(atPath: currentFile, withItemAt: tmpCurrentFile)
        } catch {
            try? FileManager.default.removeItem(atPath: tmpCurrentFile)
            throw error
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
}
