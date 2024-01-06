//
//  SubscriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {
    @Bindable var subscription: Subscription
    @Environment(\.modelContext) var modelContext
    @Query var queue: [QueueEntry]

    func addVideoToQueue(_ video: Video) {
        QueueManager.insertQueueEntries(
            videos: [video],
            queue: queue,
            modelContext: modelContext)
        // TODO: potentially delete inbox entry here?
    }

    var body: some View {
        VStack {
            List {
                Section {
                    Picker("newVideos",
                           selection: $subscription.placeVideosIn) {
                        ForEach(VideoPlacement.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                }

                Section {
                    ForEach(subscription.videos.sorted(by: { ($0.publishedDate ?? Date.distantPast)
                                                        > ($1.publishedDate ?? Date.distantPast)})
                    ) { video in
                        VideoListItem(video: video)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    addVideoToQueue(video)
                                } label: {
                                    Image(systemName: "text.badge.plus")
                                }
                                .tint(.teal)
                            }
                    }
                }
            }
            .listStyle(.plain)
            Spacer()

        }
        .navigationBarTitle(subscription.title)
        .toolbarBackground(Color.backgroundColor, for: .navigationBar)
    }
}

#Preview {
    NavigationView {
        SubscriptionDetailView(subscription: Subscription.dummy)
    }
}
