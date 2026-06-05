import Foundation

// MARK: - Config

enum RestartCodexAfterSwitch: String {
    case ask
    case auto
    case off
}

struct AppConfig {
    var refreshIntervalMinutes: Int = 30
    var minRefreshIntervalSeconds: Int = 30
    var alert5hThreshold: Int = 30    // alert when 5h remaining < this %
    var alertWeekThreshold: Int = 10  // alert when week remaining < this %
    var restartCodexAfterSwitch: RestartCodexAfterSwitch = .ask

    private static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex")
    private static let configURL = configDirectory.appendingPathComponent("switcher.json")

    static func load() -> AppConfig {
        var config = AppConfig()
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return config }
        if let v = json["refresh_interval_minutes"] as? Int, v >= 0 { config.refreshIntervalMinutes = v }
        if let v = json["min_refresh_interval_seconds"] as? Int, v > 0 { config.minRefreshIntervalSeconds = v }
        if let v = json["alert_5h_threshold"] as? Int { config.alert5hThreshold = v }
        if let v = json["alert_week_threshold"] as? Int { config.alertWeekThreshold = v }
        if let v = json["restart_codex_after_switch"] as? String,
           let mode = RestartCodexAfterSwitch(rawValue: v) {
            config.restartCodexAfterSwitch = mode
        }
        return config
    }

    func save() throws {
        let json: [String: Any] = [
            "refresh_interval_minutes": refreshIntervalMinutes,
            "min_refresh_interval_seconds": minRefreshIntervalSeconds,
            "alert_5h_threshold": alert5hThreshold,
            "alert_week_threshold": alertWeekThreshold,
            "restart_codex_after_switch": restartCodexAfterSwitch.rawValue
        ]
        let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        try FileManager.default.createDirectory(at: AppConfig.configDirectory, withIntermediateDirectories: true)
        try data.write(to: AppConfig.configURL, options: .atomic)
    }
}
