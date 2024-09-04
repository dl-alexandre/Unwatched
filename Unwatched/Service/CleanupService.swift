//
//  CleanupService.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import OSLog

struct CleanupService {
    static func cleanupDuplicatesAndInboxDate(
        _ container: ModelContainer,
        onlyIfDuplicateEntriesExist: Bool = false
    ) -> Task<
        RemovedDuplicatesInfo,
        Never
    > {
        return Task(priority: .background) {
            let repo = CleanupActor(modelContainer: container)
            let info = await repo.removeAllDuplicates(onlyIfDuplicateEntriesExist: onlyIfDuplicateEntriesExist)
            await repo.cleanupInboxEntryDates()
            return info
        }
    }
}

@ModelActor actor CleanupActor {
    var duplicateInfo = RemovedDuplicatesInfo()

    func cleanupInboxEntryDates() {
        let fetch = FetchDescriptor<InboxEntry>(predicate: #Predicate { $0.date == nil })
        guard let entries = try? modelContext.fetch(fetch) else {
            Logger.log.info("No inbox entries to cleanup dates")
            return
        }
        for entry in entries {
            entry.date = entry.video?.publishedDate
        }
        try? modelContext.save()
    }

    func removeAllDuplicates(onlyIfDuplicateEntriesExist: Bool = false) -> RemovedDuplicatesInfo {
        duplicateInfo = RemovedDuplicatesInfo()

        if onlyIfDuplicateEntriesExist && !hasDuplicateEntries() {
            Logger.log.info("Has duplicate inbox entries")
            return duplicateInfo
        }
        Logger.log.info("removing duplicates now")

        removeSubscriptionDuplicates()
        removeVideoDuplicates()
        // Keep empty queue/inbox entries
        // they can be empty due to sync, don't remove them
        try? modelContext.save()

        return duplicateInfo
    }

    private func hasDuplicateEntries() -> Bool {
        return hasDuplicateInboxEntries() || hasDuplicateUpperQueueEntries()
    }

    private func hasDuplicateUpperQueueEntries() -> Bool {
        let sort = SortDescriptor<QueueEntry>(\.order)
        var fetch = FetchDescriptor<QueueEntry>(sortBy: [sort])
        fetch.fetchLimit = 15

        if let entries = try? modelContext.fetch(fetch) {
            let duplicates = getDuplicates(from: entries, keySelector: { $0.video?.youtubeId })
            return !duplicates.isEmpty
        }
        return false
    }

    private func hasDuplicateInboxEntries() -> Bool {
        let fetch = FetchDescriptor<InboxEntry>()
        if let entries = try? modelContext.fetch(fetch) {
            let duplicates = getDuplicates(from: entries, keySelector: { $0.video?.youtubeId })
            return !duplicates.isEmpty
        }
        return false
    }

    func getDuplicates<T: Equatable>(from items: [T],
                                     keySelector: (T) -> AnyHashable,
                                     sort: (([T]) -> [T])? = nil) -> [T] {
        var removableDuplicates: [T] = []
        let grouped = Dictionary(grouping: items, by: keySelector)
        for (_, group) in grouped where group.count > 1 {
            var sortedGroup = group
            if let sort = sort {
                sortedGroup = sort(group)
            }
            let keeper = sortedGroup.first
            let removableItems = sortedGroup.filter { $0 != keeper }
            removableDuplicates.append(contentsOf: removableItems)
        }
        return removableDuplicates
    }

    // MARK: Entries
    func removeEmptyQueueEntries() {
        let fetch = FetchDescriptor<QueueEntry>(predicate: #Predicate { $0.video == nil })
        if let entries = try? modelContext.fetch(fetch) {
            duplicateInfo.countQueueEntries = entries.count
            for entry in entries {
                modelContext.delete(entry)
            }
        }
    }

    func removeEmptyInboxEntries() {
        let fetch = FetchDescriptor<InboxEntry>(predicate: #Predicate { $0.video == nil })
        if let entries = try? modelContext.fetch(fetch) {
            duplicateInfo.countInboxEntries = entries.count
            for entry in entries {
                modelContext.delete(entry)
            }
        }
    }

    // MARK: Subscription
    func removeSubscriptionDuplicates() {
        let fetch = FetchDescriptor<Subscription>()
        guard let subs = try? modelContext.fetch(fetch) else {
            return
        }
        let duplicates = getDuplicates(from: subs, keySelector: {
            ($0.youtubeChannelId ?? "") + ($0.youtubePlaylistId ?? "")
        }, sort: sortSubscriptions)
        duplicateInfo.countSubscriptions = duplicates.count
        for duplicate in duplicates {
            if let videos = duplicate.videos {
                for video in videos {
                    deleteVideo(video)
                }
            }
            modelContext.delete(duplicate)
        }
    }

    func sortSubscriptions(_ subs: [Subscription]) -> [Subscription] {
        subs.sorted { (sub0: Subscription, sub1: Subscription) -> Bool in
            let count0 = sub0.videos?.count ?? 0
            let count1 = sub1.videos?.count ?? 0
            if count0 != count1 {
                return count0 > count1
            }

            let now = Date.now
            let date0 = sub0.subscribedDate ?? now
            let date1 = sub1.subscribedDate ?? now
            if date0 != date1 {
                return date0 > date1
            }

            return sub1.isArchived
        }
    }

    // MARK: Videos
    func removeVideoDuplicates() {
        let fetch = FetchDescriptor<Video>()
        guard let videos = try? modelContext.fetch(fetch) else {
            return
        }
        let duplicates = getDuplicates(from: videos, keySelector: {
            ($0.url?.absoluteString ?? "") + ($0.subscription?.youtubePlaylistId ?? "")
        }, sort: sortVideos)
        duplicateInfo.countVideos = duplicates.count
        for duplicate in duplicates {
            deleteVideo(duplicate)
        }
    }

    func sortVideos(_ videos: [Video]) -> [Video] {
        videos.sorted { (vid0: Video, vid1: Video) -> Bool in
            let sub0 = vid0.subscription != nil
            let sub1 = vid1.subscription != nil
            if sub0 != sub1 {
                return sub1
            }

            if vid0.watched != vid1.watched {
                return vid1.watched
            }

            let cleared0 = vid0.clearedInboxDate != nil
            let cleared1 = vid1.clearedInboxDate != nil
            if cleared0 != cleared1 {
                return cleared1
            }

            let sec0 = vid0.elapsedSeconds ?? 0
            let sec1 = vid1.elapsedSeconds ?? 0
            if sec0 != sec1 {
                return sec0 > sec1
            }

            let queue0 = vid0.queueEntry != nil
            let queue1 = vid1.queueEntry != nil
            if queue0 != queue1 {
                return queue1
            }

            let inbox1 = vid1.inboxEntry != nil
            return inbox1
        }
    }

    func deleteVideo(_ video: Video) {
        if let entry = video.inboxEntry {
            modelContext.delete(entry)
        }
        if let entry = video.queueEntry {
            modelContext.delete(entry)
        }
        modelContext.delete(video)
    }
}

struct RemovedDuplicatesInfo {
    var countVideos: Int = 0
    var countQueueEntries: Int = 0
    var countInboxEntries: Int = 0
    var countSubscriptions: Int = 0
}
