import Foundation
import SwiftData

class SubscriptionService {
    static func addSubscriptions(from urls: [URL], modelContainer: ModelContainer) async throws -> [SubscriptionState] {
        // TODO: should this run in the Bg? Maybe return a task with the subsciptionStates
        // maybe even an array of tasks that automatically updates the UI?
        let repo = SubscriptionActor(modelContainer: modelContainer)
        return try await repo.addSubscriptions(from: urls)
    }

    static func getAllFeedUrls(_ container: ModelContainer) async throws -> [(title: String, link: URL)] {
        let repo = SubscriptionActor(modelContainer: container)
        return try await repo.getAllFeedUrls()
    }
}
