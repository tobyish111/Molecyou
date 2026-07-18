import Foundation

struct AnalyticsEvent: Sendable, Equatable {
    let name: String
    let properties: [String: String]

    static func screenViewed(_ screen: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "screen_viewed", properties: ["screen": screen])
    }
}

protocol AnalyticsTracking: Sendable {
    func track(_ event: AnalyticsEvent)
}

struct NoOpAnalyticsTracker: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}
