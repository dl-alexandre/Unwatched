//
//  ContentView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false

    @Environment(\.colorScheme) var colorScheme
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?
    @Environment(SheetPositionReader.self) var sheetPos

    var body: some View {
        @Bindable var navManager = navManager
        let videoExists = player.video != nil
        let bigScreen = sizeClass == .regular && !UIDevice.isIphone

        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let layout = isLandscape
                ? AnyLayout(HStackLayout())
                : AnyLayout(VStackLayout())
            let landscapeFullscreen = !bigScreen && isLandscape

            let chapterViewDetent: Set<PresentationDetent> = player.embeddingDisabled
                ? [.medium]
                : [.height(sheetPos.playerControlHeight)]

            ZStack {
                layout {
                    VideoPlayer(
                        compactSize: bigScreen,
                        showInfo: !bigScreen || (isLandscape && bigScreen) && !hideControlsFullscreen,
                        horizontalLayout: hideControlsFullscreen,
                        landscapeFullscreen: landscapeFullscreen
                    )
                    .frame(maxHeight: .infinity)

                    if bigScreen && !hideControlsFullscreen {
                        MenuView()
                            .frame(maxWidth: isLandscape
                                    ? min(proxy.size.width * 0.4, 400)
                                    : nil)
                            .setColorScheme()
                    }
                }
                if !bigScreen && !videoExists {
                    VideoNotAvailableView()
                }
            }
            .animation(.default, value: hideControlsFullscreen)
            .background(Color.playerBackgroundColor)
            .setColorScheme(forPlayer: true)
            .onAppear {
                sheetPos.setTopSafeArea(proxy.safeAreaInsets.top)
            }
            .sheet(isPresented: $navManager.showDescriptionDetail) {
                if let video = player.video {
                    ChapterDescriptionView(video: video, page: $navManager.selectedDetailPage)
                        .presentationDetents(chapterViewDetent)
                        .presentationBackgroundInteraction(
                            .enabled(upThrough: .height(sheetPos.playerControlHeight))
                        )
                        .presentationDragIndicator(.visible)
                        .environment(\.colorScheme, colorScheme)
                }
            }
            .menuViewSheet(allowMaxSheetHeight: videoExists && !navManager.searchFocused,
                           embeddingDisabled: player.embeddingDisabled,
                           showCancelButton: landscapeFullscreen,
                           disableSheet: bigScreen
            )
        }
        .setColorScheme()
        .ignoresSafeArea(bigScreen ? .keyboard : [])
        .innerSizeTrackerModifier(onChange: { newSize in
            sheetPos.sheetHeight = newSize.height
        })
    }
}

#Preview {
    let player = PlayerManager()
    player.video = Video.getDummy()

    return ContentView(hideControlsFullscreen: false)
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(Alerter())
        .environment(player)
        .environment(ImageCacheManager())
        .environment(RefreshManager())
        .environment(SheetPositionReader())
}
