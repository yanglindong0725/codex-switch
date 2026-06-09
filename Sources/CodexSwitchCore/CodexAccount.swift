import AppKit
import Foundation

public struct CodexAccount {
    public let alias: String
    public let email: String
    public let plan: String
    public let authMode: String
    public let accountId: String
    public let accessToken: String
    public let subscriptionStart: String?
    public let subscriptionUntil: String?
    public let daysRemaining: Int?
    public let tokenExpiry: Date?

    public init(alias: String, email: String, plan: String, authMode: String, accountId: String, accessToken: String, subscriptionStart: String?, subscriptionUntil: String?, daysRemaining: Int?, tokenExpiry: Date?) {
        self.alias = alias
        self.email = email
        self.plan = plan
        self.authMode = authMode
        self.accountId = accountId
        self.accessToken = accessToken
        self.subscriptionStart = subscriptionStart
        self.subscriptionUntil = subscriptionUntil
        self.daysRemaining = daysRemaining
        self.tokenExpiry = tokenExpiry
    }

    public var isTokenExpired: Bool {
        guard let exp = tokenExpiry else { return false }
        return exp < Date()
    }

    public var planColor: NSColor {
        switch normalizedPlan {
        case "enterprise": return NSColor(red: 0.45, green: 0.38, blue: 0.95, alpha: 1.0)
        case "business": return NSColor(red: 0.15, green: 0.45, blue: 0.75, alpha: 1.0)
        case "team": return NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
        case "pro": return NSColor(red: 0.6, green: 0.35, blue: 0.9, alpha: 1.0)
        case "plus": return NSColor(red: 0.2, green: 0.75, blue: 0.5, alpha: 1.0)
        case "go": return NSColor(red: 0.2, green: 0.65, blue: 0.7, alpha: 1.0)
        case "free": return NSColor.secondaryLabelColor
        default: return .secondaryLabelColor
        }
    }

    public var normalizedPlan: String {
        switch plan.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "free": return "free"
        case "go": return "go"
        case "plus": return "plus"
        case "pro", "prolite": return "pro"
        case "team": return "team"
        case "business": return "business"
        case "enterprise": return "enterprise"
        default: return "unknown"
        }
    }

    public var planLabel: String { normalizedPlan.uppercased() }
}
