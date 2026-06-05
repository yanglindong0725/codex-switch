import Foundation

// MARK: - Rate Limit Client

class RateLimitClient {
    private let apiURL = "https://chatgpt.com/backend-api/wham/usage"
    var usageByAlias: [String: FetchState] = [:]
    var lastFetchTime: Date?
    var onUpdate: (() -> Void)?

    func fetchAll(_ accounts: [CodexAccount]) {
        lastFetchTime = Date()
        for acct in accounts {
            if acct.accessToken.isEmpty || acct.accountId == "?" {
                usageByAlias[acct.alias] = .failed("缺少登录凭据")
                continue
            }
            // Only show loading if no previous data
            if usageByAlias[acct.alias] == nil { usageByAlias[acct.alias] = .loading }
            fetchForAccount(acct)
        }
        DispatchQueue.main.async { self.onUpdate?() }
    }

    func refreshIfNeeded(_ accounts: [CodexAccount], minInterval: TimeInterval) {
        if let last = lastFetchTime, Date().timeIntervalSince(last) < minInterval { return }
        fetchAll(accounts)
    }

    private func fetchForAccount(_ acct: CodexAccount) {
        guard let url = URL(string: apiURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(acct.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(acct.accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("codex-switcher/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let alias = acct.alias
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if error != nil { self.setState(alias, .failed("网络错误")); return }
            guard let http = response as? HTTPURLResponse, let data = data else {
                self.setState(alias, .failed("无响应")); return
            }
            if http.statusCode == 401 { self.setState(alias, .failed("Token 已过期")); return }
            if http.statusCode != 200 { self.setState(alias, .failed("HTTP \(http.statusCode)")); return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.setState(alias, .failed("解析失败")); return
            }
            self.setState(alias, .success(self.parseResponse(json)))
        }.resume()
    }

    private func setState(_ alias: String, _ state: FetchState) {
        DispatchQueue.main.async { self.usageByAlias[alias] = state; self.onUpdate?() }
    }

    private func parseResponse(_ json: [String: Any]) -> RateLimitInfo {
        var primary: RateLimitWindow? = nil; var secondary: RateLimitWindow? = nil
        if let rl = json["rate_limit"] as? [String: Any] {
            primary = parseWindow(rl["primary_window"])
            secondary = parseWindow(rl["secondary_window"])
        }
        var credits: CreditsSnapshot? = nil
        if let c = json["credits"] as? [String: Any] {
            credits = CreditsSnapshot(hasCredits: c["has_credits"] as? Bool ?? false,
                unlimited: c["unlimited"] as? Bool ?? false, balance: c["balance"] as? String)
        }
        return RateLimitInfo(primary: primary, secondary: secondary, credits: credits, planType: json["plan_type"] as? String)
    }

    private func parseWindow(_ obj: Any?) -> RateLimitWindow? {
        guard let w = obj as? [String: Any] else { return nil }
        return RateLimitWindow(usedPercent: w["used_percent"] as? Int ?? 0,
            resetsAt: (w["reset_at"] as? Double).map { Date(timeIntervalSince1970: $0) })
    }
}
