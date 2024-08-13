//
//  QueueView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct QueueView: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme
    @AppStorage(Const.newQueueItemsCount) var newQueueItemsCount = 0
    @AppStorage(Const.showClearQueueButton) var showClearQueueButton: Bool = true

    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) private var player
    @Query(sort: \QueueEntry.order, animation: .default) var queue: [QueueEntry]

    var showCancelButton: Bool = false

    var body: some View {
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedSubscriptionQueue) {
            ZStack {
                Color.backgroundColor.ignoresSafeArea(.all)

                if queue.isEmpty {
                    contentUnavailable
                    InboxHasEntriesTip()
                }
                // Potential Workaround: always showing the list might avoid a crash
                List {
                    ForEach(queue) { entry in
                        ZStack {
                            if let video = entry.video {
                                VideoListItem(
                                    video,
                                    config: VideoListItemConfig(
                                        videoDuration: video.duration,
                                        clearRole: .destructive,
                                        onChange: handleVideoChange,
                                        clearAboveBelowList: .queue
                                    )
                                )
                            }
                        }
                        .id(NavigationManager.getScrollId(entry.video?.youtubeId, "queue"))
                    }
                    .onMove(perform: moveQueueEntry)
                    .handleDynamicVideoURLDrop(.queue)
                    .listRowBackground(Color.backgroundColor)

                    if showClearQueueButton && queue.count >= Const.minListEntriesToShowClear {
                        ClearAllVideosButton(clearAll: clearAll)
                    }
                }
                .disabled(queue.isEmpty)
            }
            .myNavigationTitle("queue", showBack: false)
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
                    .foregroundStyle(Color.neutralAccentColor)
            }
            .toolbar {
                if showCancelButton {
                    DismissToolbarButton()
                }
                RefreshToolbarButton()
            }
            .tint(theme.color)
        }
        .tint(.neutralAccentColor)
        .listStyle(.plain)
        .onAppear {
            navManager.setScrollId(queue.first?.video?.youtubeId, "queue")
        }
        .onDisappear {
            newQueueItemsCount = 0
        }
    }

    var contentUnavailable: some View {
        ContentUnavailableView {
            Label("noQueueItems", systemImage: "rectangle.stack.badge.play.fill")
        } description: {
            Text("noQueueItemsDescription")
        } actions: {
            SetupShareSheetAction()
                .buttonStyle(.borderedProminent)

            DisappearingAddFeedsMenu()
                .bold()
        }
        .contentShape(Rectangle())
        .handleVideoUrlDrop(.queue)
    }

    func handleVideoChange() {
        if newQueueItemsCount > 0 {
            withAnimation {
                newQueueItemsCount = 0
            }
        }
    }

    func moveQueueEntry(from source: IndexSet, to destination: Int) {
        let task = VideoService.moveQueueEntry(from: source,
                                               to: destination,
                                               modelContext: modelContext)
        if destination == 0 || source.contains(0) {
            player.loadTopmostVideoFromQueue(after: task)
        }
        handleVideoChange()
    }

    func clearAll() {
        VideoService.deleteQueueEntries(queue, modelContext: modelContext)
        handleVideoChange()
    }
}

#Preview {
    QueueView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
}
