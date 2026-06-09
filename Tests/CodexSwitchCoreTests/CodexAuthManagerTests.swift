import XCTest
@testable import CodexSwitchCore

final class CodexAuthManagerTests: XCTestCase {
    func testSyncAddsNewAccountWithoutDeletingExistingAccount() throws {
        try withFixture { fixture in
            try fixture.writeAccount(alias: "first", email: "first@example.com", accountId: "acct-first")
            try fixture.writeAuth(email: "second@example.com", accountId: "acct-second")

            XCTAssertEqual(try fixture.manager.syncAuthToAccounts(), .saved(alias: "second"))

            XCTAssertTrue(fixture.fileExists(fixture.accountPath("first")))
            XCTAssertTrue(fixture.fileExists(fixture.accountPath("second")))
            XCTAssertEqual(fixture.manager.currentAlias(), "second")
        }
    }

    func testSyncRefreshesSameEmailAndAccountIdInPlace() throws {
        try withFixture { fixture in
            try fixture.writeAccount(alias: "primary", email: "user@example.com", accountId: "acct-same", accessToken: "old-token")
            try fixture.writeAuth(email: "user@example.com", accountId: "acct-same", accessToken: "new-token")

            XCTAssertEqual(try fixture.manager.syncAuthToAccounts(), .saved(alias: "primary"))

            XCTAssertEqual(fixture.manager.listAccounts().map(\.alias), ["primary"])
            XCTAssertEqual(fixture.manager.parseAccountFile(fixture.accountPath("primary"), alias: "primary")?.accessToken, "new-token")
            XCTAssertEqual(fixture.manager.currentAlias(), "primary")
        }
    }

    func testSyncDoesNotOverwriteSameEmailDifferentAccountId() throws {
        try withFixture { fixture in
            try fixture.writeAccount(alias: "user", email: "user@example.com", accountId: "acct-original")
            try fixture.writeAuth(email: "user@example.com", accountId: "acct-new")

            XCTAssertEqual(try fixture.manager.syncAuthToAccounts(), .saved(alias: "user1"))

            let accounts = fixture.manager.listAccounts().sorted { $0.alias < $1.alias }
            XCTAssertEqual(accounts.map(\.alias), ["user", "user1"])
            XCTAssertEqual(fixture.manager.parseAccountFile(fixture.accountPath("user"), alias: "user")?.accountId, "acct-original")
            XCTAssertEqual(fixture.manager.parseAccountFile(fixture.accountPath("user1"), alias: "user1")?.accountId, "acct-new")
            XCTAssertEqual(fixture.manager.currentAlias(), "user1")
        }
    }

    func testInvalidAuthDoesNotChangeCurrentOrDeleteAccounts() throws {
        try withFixture { fixture in
            try fixture.writeAccount(alias: "existing", email: "existing@example.com", accountId: "acct-existing")
            try "existing".write(toFile: fixture.currentPath, atomically: true, encoding: .utf8)
            try "{}".write(toFile: fixture.manager.authFile, atomically: true, encoding: .utf8)

            XCTAssertEqual(try fixture.manager.syncAuthToAccounts(), .invalidAuth)

            XCTAssertTrue(fixture.fileExists(fixture.accountPath("existing")))
            XCTAssertEqual(fixture.manager.currentAlias(), "existing")
            XCTAssertEqual(fixture.manager.listAccounts().map(\.alias), ["existing"])
        }
    }

    func testPrepareForNewLoginDoesNotRemoveInvalidAuth() throws {
        try withFixture { fixture in
            try "{}".write(toFile: fixture.manager.authFile, atomically: true, encoding: .utf8)

            XCTAssertThrowsError(try fixture.manager.prepareForNewLogin()) { error in
                XCTAssertEqual(error as? CodexAuthManagerError, .invalidAuth)
            }
            XCTAssertTrue(fixture.fileExists(fixture.manager.authFile))
        }
    }

    func testSingleInstanceLockBlocksSecondAcquireAndReleases() throws {
        try withFixture { fixture in
            let first = CodexSwitchInstanceLock(codexDir: fixture.tempDir.path)
            let second = CodexSwitchInstanceLock(codexDir: fixture.tempDir.path)

            XCTAssertTrue(try first.acquire())
            XCTAssertFalse(try second.acquire())

            first.release()
            XCTAssertTrue(try second.acquire())
        }
    }

    private func withFixture(_ body: (Fixture) throws -> Void) throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        try body(fixture)
    }
}

private final class Fixture {
    let tempDir: URL
    let manager: CodexAuthManager
    private let fm = FileManager.default

    var currentPath: String {
        tempDir.appendingPathComponent("current").path
    }

    init() throws {
        tempDir = fm.temporaryDirectory.appendingPathComponent("codex-switch-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        manager = CodexAuthManager(codexDir: tempDir.path)
        try fm.createDirectory(atPath: manager.accountsDir, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? fm.removeItem(at: tempDir)
    }

    func fileExists(_ path: String) -> Bool {
        fm.fileExists(atPath: path)
    }

    func writeAccount(alias: String, email: String, accountId: String, accessToken: String = "access-token") throws {
        try authJSON(email: email, accountId: accountId, accessToken: accessToken)
            .write(toFile: accountPath(alias), atomically: true, encoding: .utf8)
    }

    func writeAuth(email: String, accountId: String, accessToken: String = "access-token") throws {
        try authJSON(email: email, accountId: accountId, accessToken: accessToken)
            .write(toFile: manager.authFile, atomically: true, encoding: .utf8)
    }

    func accountPath(_ alias: String) -> String {
        "\(manager.accountsDir)/\(alias).json"
    }

    private func authJSON(email: String, accountId: String, accessToken: String) throws -> String {
        let idToken = try jwt(email: email)
        let object: [String: Any] = [
            "auth_mode": "oauth",
            "tokens": [
                "account_id": accountId,
                "access_token": accessToken,
                "id_token": idToken
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(data: data, encoding: .utf8)!
    }

    private func jwt(email: String) throws -> String {
        let header = try base64URL(["alg": "none"])
        let payload = try base64URL([
            "email": email,
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_plan_type": "plus"
            ]
        ])
        return "\(header).\(payload).signature"
    }

    private func base64URL(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
