//
//  SubscriptionManager.swift
//  Unwatched
//

import Foundation
import SwiftData

@ModelActor
actor SubscriptionActor {
    func subscribeTo(_ channelId: String?, _ subsciptionId: PersistentIdentifier?) async throws {
        // check if it already exists, if it does, subscribe
        if let id = subsciptionId, let sub = modelContext.model(for: id) as? Subscription {
            sub.isArchived = false
            print("successfully subscribed via subId")
            try modelContext.save()
            return
        }

        guard let channelId = channelId else {
            throw SubscriptionError.noInfoFoundToSubscribeTo
        }
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate { $0.youtubeChannelId == channelId })
        let subs = try? modelContext.fetch(fetch)
        if let first = subs?.first {
            first.isArchived = false
        }

        // if it doesn't exist get url and run the regular subscription flow
        let feedUrl = try SubscriptionActor.getFeedUrlFromChannelId(channelId)
        let subStates = try await addSubscriptions(from: [feedUrl])
        if let first = subStates.first {
            if !(first.success || first.alreadyAdded) {
                throw SubscriptionError.couldNotSubscribe(first.error ?? "unknown")
            }
        }
        try modelContext.save()
    }

    func addSubscriptions(from urls: [URL]) async throws -> [SubscriptionState] {
        var subscriptionStates = [SubscriptionState]()

        try await withThrowingTaskGroup(of: (SubscriptionState, SendableSubscription?).self) { group in
            for url in urls {
                group.addTask {
                    return await self.loadSubscriptionInfo(from: url, unarchiveSubIfAvailable: true)
                }
            }

            for try await (subState, sendableSub) in group {
                subscriptionStates.append(subState)
                if let sendableSub = sendableSub {
                    let sub = sendableSub.getSubscription()
                    modelContext.insert(sub)
                }
            }
        }
        try modelContext.save()
        return subscriptionStates
    }

    func loadSubscriptionInfo(
        from url: URL,
        unarchiveSubIfAvailable: Bool = false
    ) async -> (SubscriptionState, SendableSubscription?) {
        var subState = SubscriptionState(url: url)
        do {
            subState.userName = SubscriptionActor.getChannelUserNameFromUrl(url: url)
            if let title = getTitleIfSubscriptionExists(
                userName: subState.userName, unarchiveSubIfAvailable
            ) {
                print("found existing sub via userName")
                subState.title = title
                subState.alreadyAdded = true
                return (subState, nil)
            }

            if let sendableSub = try await SubscriptionActor.getSubscription(url: url, userName: subState.userName) {
                if let channelId = sendableSub.youtubeChannelId,
                   let title = getTitleIfSubscriptionExists(channelId: channelId, unarchiveSubIfAvailable) {
                    print("found existing sub via channelId")
                    subState.title = title
                    subState.alreadyAdded = true
                    return (subState, sendableSub)
                }

                subState.title = sendableSub.title
                subState.success = true
                return (subState, sendableSub)
            }
        } catch {
            subState.error = error.localizedDescription
        }
        return (subState, nil)
    }

    func getTitleIfSubscriptionExists(channelId: String? = nil,
                                      userName: String? = nil,
                                      _ unarchiveSubIfAvailable: Bool = false) -> String? {
        if channelId == nil && userName == nil { return nil }
        let fetchDescriptor = FetchDescriptor<Subscription>(predicate: #Predicate {
            (channelId != nil && channelId == $0.youtubeChannelId) ||
                (userName != nil && $0.youtubeUserName == userName)
        })
        let subs = try? modelContext.fetch(fetchDescriptor)
        if let sub = subs?.first {
            if unarchiveSubIfAvailable {
                sub.isArchived = false
            }
            let title = sub.title
            return title
        }
        return nil
    }

    static func getSubscription(url: URL, userName: String? = nil) async throws -> SendableSubscription? {
        let feedUrl = try await SubscriptionActor.getChannelFeedFromUrl(url: url, userName: userName)
        return try await VideoCrawler.loadSubscriptionFromRSS(feedUrl: feedUrl)
    }

    static func getChannelFeedFromUrl(url: URL, userName: String?) async throws -> URL {
        if isYoutubeFeedUrl(url: url) {
            return url
        }
        guard let userName = userName else {
            throw SubscriptionError.failedGettingChannelIdFromUsername("Username was empty")
        }
        let channelId = try await YoutubeDataAPI.getYtChannelId(from: userName)
        return try SubscriptionActor.getFeedUrlFromChannelId(channelId)
    }

    static func getFeedUrlFromChannelId(_ channelId: String) throws -> URL {
        if let channelFeedUrl = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelId)") {
            return channelFeedUrl
        }
        throw SubscriptionError.notSupported
    }

    static func getChannelUserNameFromUrl(url: URL) -> String? {
        let urlString = url.absoluteString

        // https://www.youtube.com/@GAMERTAGVR/videos
        if let userName = urlString.matching(regex: #"\/@([^\/#\?]*)"#) {
            return userName
        }

        // https://www.youtube.com/c/GamertagVR/videos
        if let userName = urlString.matching(regex: #"\/c\/([^\/]*)"#) {
            return userName
        }

        // https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
        if let userName = urlString.matching(regex: #"\/videos.xml\?user=(.*)"#) {
            return userName
        }

        return nil
    }

    static func isYoutubeFeedUrl(url: URL) -> Bool {
        // https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
        // https://www.youtube.com/feeds/videos.xml?channel_id=UCnrAvt4i_2WV3yEKWyEUMlg
        return url.absoluteString.contains("youtube.com/feeds/videos.xml")
    }

    func getAllFeedUrls() throws -> [(title: String, link: URL)] {
        let fetchDescriptor = FetchDescriptor<Subscription>()
        let subs = try modelContext.fetch(fetchDescriptor)
        return subs.map { (title: $0.title, link: $0.link) }
    }

    func unsubscribe(_ channelId: String) throws {
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == channelId
        })
        guard let first = try modelContext.fetch(fetch).first else {
            print("nothing found to unsubscribe")
            return
        }
        try deleteSubscriptions([first.persistentModelID])
    }

    func deleteSubscriptions(_ subscriptionIds: [PersistentIdentifier]) throws {
        for subscriptionId in subscriptionIds {
            guard let sub = modelContext.model(for: subscriptionId) as? Subscription else {
                continue
            }

            for video in sub.videos {
                if video.queueEntry == nil && !video.watched {
                    if let inboxEntry = video.inboxEntry {
                        modelContext.delete(inboxEntry)
                    }
                    modelContext.delete(video)
                }
            }
            sub.mostRecentVideoDate = nil
            sub.isArchived = true
        }
        try modelContext.save()
    }
}
