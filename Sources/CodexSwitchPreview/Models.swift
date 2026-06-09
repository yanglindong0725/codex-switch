import AppKit
import CodexSwitchCore
import Foundation

// MARK: - 数据模型

public typealias CodexAccount = CodexSwitchCore.CodexAccount

public struct RateLimitWindow {
    public let usedPercent: Int
    public let resetsAt: Date?

    public init(usedPercent: Int, resetsAt: Date?) {
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }

    public var remaining: Int { 100 - min(max(usedPercent, 0), 100) }

    public var barColor: NSColor {
        if remaining <= 10 { return NSColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1.0) }
        if remaining <= 25 { return NSColor(red: 0.95, green: 0.6, blue: 0.2, alpha: 1.0) }
        if remaining <= 50 { return NSColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1.0) }
        if remaining <= 75 { return NSColor(red: 0.3, green: 0.78, blue: 0.5, alpha: 1.0) }
        return NSColor(red: 0.25, green: 0.72, blue: 0.45, alpha: 1.0)
    }

    public var textColor: NSColor {
        if remaining <= 10 { return NSColor(red: 0.9, green: 0.25, blue: 0.25, alpha: 1.0) }
        if remaining <= 25 { return NSColor(red: 0.85, green: 0.5, blue: 0.15, alpha: 1.0) }
        return NSColor.secondaryLabelColor
    }
}

public struct CreditsSnapshot {
    public let hasCredits: Bool
    public let unlimited: Bool
    public let balance: String?

    public init(hasCredits: Bool, unlimited: Bool, balance: String?) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }
}

public struct RateLimitInfo {
    public let primary: RateLimitWindow?
    public let secondary: RateLimitWindow?
    public let credits: CreditsSnapshot?
    public let planType: String?

    public init(primary: RateLimitWindow?, secondary: RateLimitWindow?, credits: CreditsSnapshot?, planType: String?) {
        self.primary = primary
        self.secondary = secondary
        self.credits = credits
        self.planType = planType
    }
}

public enum FetchState {
    case idle
    case loading
    case success(RateLimitInfo)
    case failed(String)
}
