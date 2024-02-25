//
//  ChapterSelection.swift
//  Unwatched
//

import SwiftUI

enum ChapterDescriptionPage {
    case description
    case chapters
}

struct ChapterDescriptionView: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(PlayerManager.self) var player
    @Environment(\.dismiss) var dismiss

    @State var selectedDetailPageTask: Task<ChapterDescriptionPage, Never>?

    @GestureState private var dragState: CGFloat = 0

    var body: some View {
        NavigationStack {
            if let video = player.video {
                let hasChapters = video.chapters?.isEmpty == false
                let hasDescription = video.videoDescription != nil
                let sorted = video.sortedChapters

                ScrollView {
                    if navManager.selectedDetailPage == .chapters {
                        if !sorted.isEmpty {
                            chapterList(sorted)
                                .padding(.horizontal)
                                .transition(.move(edge: .trailing))
                        }
                    } else {
                        DescriptionDetailView(video: video)
                            .transition(.move(edge: .leading))
                    }
                }
                .highPriorityGesture(dragGesture(origin: navManager.selectedDetailPage))
                .toolbar {
                    if hasDescription && hasChapters {
                        @Bindable var navManager = navManager
                        ToolbarItem(placement: .principal) {
                            Picker("page", selection: $navManager.selectedDetailPage) {
                                Text("description").tag(ChapterDescriptionPage.description)
                                Text("chapters").tag(ChapterDescriptionPage.chapters)
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: Const.clearSF)
                        }
                    }
                }
                .tint(Color.myAccentColor)
                .toolbarTitleDisplayMode(.inline)
            }
        }
        .task(id: selectedDetailPageTask) {
            guard let task = selectedDetailPageTask else {
                return
            }
            let direction = await task.value
            withAnimation {
                navManager.selectedDetailPage = direction
            }
        }
    }

    func chapterList(_ chapter: [Chapter]) -> some View {
        VStack {
            ForEach(chapter) { chapter in
                let isCurrent = chapter == player.currentChapter
                let foregroundColor: Color = isCurrent ? Color.backgroundColor : Color.myAccentColor
                let backgroundColor: Color = isCurrent ? Color.myAccentColor : Color.myBackgroundGray

                Button {
                    if !chapter.isActive {
                        toggleChapter(chapter)
                    } else {
                        setChapter(chapter)
                    }
                } label: {
                    ChapterListItem(chapter: chapter,
                                    toggleChapter: toggleChapter,
                                    timeText: getTimeText(chapter, isCurrent: isCurrent))
                        .padding(10)
                        .background(
                            backgroundColor
                                .clipShape(RoundedRectangle(cornerRadius: 15.0))
                        )
                        .opacity(chapter.isActive ? 1 : 0.6)
                        .id(chapter.persistentModelID)
                }
                .tint(foregroundColor)
            }
        }
    }

    func dragGesture(origin: ChapterDescriptionPage) -> some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .updating($dragState) { value, state, _ in
                let hasChapters = player.video?.chapters?.isEmpty == false
                let hasDescription = player.video?.videoDescription != nil
                if origin == .chapters && !hasDescription || origin == .description && !hasChapters {
                    return
                }

                state = value.translation.width
                if (origin == .chapters && state > 30) || (origin == .description && state < -30) {
                    selectedDetailPageTask = Task.detached {
                        let direction: ChapterDescriptionPage = origin == .description ? .chapters : .description
                        return direction
                    }
                }
            }
    }

    func toggleChapter(_ chapter: Chapter) {
        chapter.isActive.toggle()
        player.handleChapterChange()
    }

    func setChapter(_ chapter: Chapter) {
        player.setChapter(chapter)
    }

    func getTimeText(_ chapter: Chapter, isCurrent: Bool) -> String {
        guard isCurrent,
              let endTime = chapter.endTime,
              let currentTime = player.currentTime else {
            return chapter.duration?.formattedSeconds ?? ""
        }
        let remaining = endTime - currentTime
        return "\(remaining.formattedSeconds ?? "") remaining"
    }
}

#Preview {
    ChapterDescriptionView()
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager.getDummy())
        .environment(NavigationManager())
        .environment(RefreshManager())
        .environment(SubscribeManager())
        .environment(ImageCacheManager())
        .environment(SheetPositionReader())
}
