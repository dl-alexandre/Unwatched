//
//  ChapterMiniControlView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ChapterMiniControlView: View {
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @State var triggerFeedback = false

    var setShowMenu: () -> Void
    var showInfo: Bool = true

    var body: some View {
        let hasChapters = player.currentChapter != nil
        let hasAnyChapters = player.video?.chapters?.isEmpty

        VStack(spacing: 20) {
            Grid(horizontalSpacing: 5, verticalSpacing: 0) {
                GridRow {
                    if hasChapters {
                        Button(action: goToPrevious) {
                            Image(systemName: Const.previousChapterSF)
                                .font(.system(size: 15))
                        }
                        .accessibilityLabel("previousChapter")
                        .keyboardShortcut(.leftArrow)
                        .buttonStyle(ChangeChapterButtonStyle())
                        .disabled(player.previousChapterDisabled)
                    } else {
                        Color.clear.fixedSize()
                    }

                    Button {
                        let val: ChapterDescriptionPage = (player.video?.sortedChapters ?? []).isEmpty
                            ? .description
                            : .chapters
                        navManager.selectedDetailPage = val
                        navManager.showDescriptionDetail = true
                    } label: {
                        ZStack {
                            if let chapt = player.currentChapter {
                                Text(chapt.titleTextForced)
                            } else {
                                title
                            }
                        }
                        .padding(.vertical, 2)
                        .font(.system(.title2))
                        .fontWeight(.black)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                    }

                    if hasChapters {
                        ChapterMiniControlGoToNext(goToNext: goToNext)
                            .keyboardShortcut(.rightArrow)
                            .disabled(player.nextChapter == nil || player.playDisabled)
                    } else {
                        Color.clear.fixedSize()
                    }
                }

                GridRow {
                    Color.clear.fixedSize()

                    InteractiveSubscriptionTitle(video: player.video,
                                                 subscription: player.video?.subscription,
                                                 openSubscription: openSubscription)

                    if hasChapters {
                        ChapterMiniControlRemainingText()
                    } else {
                        EmptyView()
                    }
                }
            }
            .frame(maxWidth: 600)

            if showInfo, let video = player.video, !player.embeddingDisabled {
                videoDescription(video, hasChapters)
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: triggerFeedback)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .animation(.bouncy(duration: 0.5), value: player.currentChapter != nil)
        .onChange(of: hasAnyChapters) {
            if player.currentChapter == nil {
                player.handleChapterChange()
            }
        }
    }

    func openSubscription(_ sub: Subscription) {
        navManager.pushSubscription(sub)
        setShowMenu()
    }

    @ViewBuilder var title: some View {
        if let chapter = player.currentChapter {
            Text(chapter.titleTextForced)
        } else {
            Text(player.video?.title ?? "")
                .font(.system(size: 20, weight: .heavy))
                .multilineTextAlignment(.center)
                .contextMenu(menuItems: {
                    if let url = player.video?.url {
                        ShareLink(item: url) {
                            Label("shareVideo", systemImage: "square.and.arrow.up.fill")
                        }
                    }
                })
        }
    }

    func videoDescription(_ video: Video, _ hasChapters: Bool) -> some View {
        Button {
            navManager.selectedDetailPage = .description
            navManager.showDescriptionDetail = true
        } label: {
            HStack {
                Image(systemName: Const.videoDescriptionSF)
                if let published = video.publishedDate {
                    Text(Const.dotString)
                    Text(verbatim: "\(published.formatted)")
                }
                if let duration = video.duration?.formattedSeconds {
                    Text(Const.dotString)
                    Text(verbatim: "\(duration)")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                BackgroundProgressBar()
            }
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    func goToPrevious() {
        triggerFeedback.toggle()
        player.goToPreviousChapter()
    }

    func goToNext() {
        triggerFeedback.toggle()
        player.goToNextChapter()
    }
}

struct BackgroundProgressBar: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.backgroundGray

                if let elapsed = player.currentTime,
                   let total = player.video?.duration {
                    let width = (elapsed / total) * geometry.size.width

                    HStack(spacing: 0) {
                        Color.foregroundGray
                            .opacity(0.2)
                            .frame(width: width)
                            .animation(.default, value: width)
                        Color.clear
                    }
                }
            }
        }
    }
}

struct ChapterMiniControlRemainingText: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        if let remaining = player.currentRemainingText {
            Text(remaining)
                .foregroundStyle(Color.foregroundGray)
                .font(.system(size: 14))
                .lineLimit(1)
        }
    }
}

struct ChapterMiniControlGoToNext: View {
    @Environment(PlayerManager.self) var player

    var goToNext: () -> Void

    var body: some View {
        Button(action: goToNext) {
            Image(systemName: Const.nextChapterSF)
                .font(.system(size: 15))
        }
        .accessibilityLabel("nextChapter")
        .buttonStyle(ChangeChapterButtonStyle(
            chapter: player.currentChapter,
            remainingTime: player.currentRemaining
        ))
    }
}

#Preview {
    ChapterMiniControlView(setShowMenu: {})
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager.getDummy())
        .environment(NavigationManager.getDummy())
        .environment(Alerter())
}
