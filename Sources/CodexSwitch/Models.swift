import AppKit
import Foundation

// MARK: - Data Models

struct CodexAccount {
    let alias: String
    let email: String
    let plan: String
    let authMode: String
    let accountId: String
    let accessToken: String
    let subscriptionStart: String?
    let subscriptionUntil: String?
    let daysRemaining: Int?
    let tokenExpiry: Date?

    var isTokenExpired: Bool {
        guard let exp = tokenExpiry else { return false }
        return exp < Date()
    }

    var planColor: NSColor {
        switch plan {
        case "team": return NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
        case "pro": return NSColor(red: 0.6, green: 0.35, blue: 0.9, alpha: 1.0)
        case "plus": return NSColor(red: 0.2, green: 0.75, blue: 0.5, alpha: 1.0)
        default: return .secondaryLabelColor
        }
    }

    var planLabel: String { plan.uppercased() }
}

struct RateLimitWindow {
    let usedPercent: Int
    let resetsAt: Date?

    var remaining: Int { 100 - min(max(usedPercent, 0), 100) }

    var barColor: NSColor {
        if remaining <= 10 { return NSColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1.0) }
        if remaining <= 25 { return NSColor(red: 0.95, green: 0.6, blue: 0.2, alpha: 1.0) }
        if remaining <= 50 { return NSColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1.0) }
        if remaining <= 75 { return NSColor(red: 0.3, green: 0.78, blue: 0.5, alpha: 1.0) }
        return NSColor(red: 0.25, green: 0.72, blue: 0.45, alpha: 1.0)
    }

    var textColor: NSColor {
        if remaining <= 10 { return NSColor(red: 0.9, green: 0.25, blue: 0.25, alpha: 1.0) }
        if remaining <= 25 { return NSColor(red: 0.85, green: 0.5, blue: 0.15, alpha: 1.0) }
        return NSColor.secondaryLabelColor
    }
}

struct CreditsSnapshot {
    let hasCredits: Bool
    let unlimited: Bool
    let balance: String?
}

struct RateLimitInfo {
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
    let credits: CreditsSnapshot?
    let planType: String?
}

enum FetchState {
    case idle
    case loading
    case success(RateLimitInfo)
    case failed(String)
}
