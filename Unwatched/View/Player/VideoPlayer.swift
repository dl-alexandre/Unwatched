//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI

struct VideoPlayer: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(Alerter.self) private var alerter
    @Environment(PlayerManager.self) var player

    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    @AppStorage(Const.continuousPlay) var continuousPlay: Bool = false

    @GestureState private var dragState: CGFloat = 0
    @State var continuousPlayWorkaround: Bool = false
    @State var isSubscribedSuccess: Bool?
    @State var subscribeManager = SubscribeManager()

    @Binding var showMenu: Bool

    var body: some View {
        @Bindable var player = player

        VStack(spacing: 10) {
            VStack(spacing: 10) {
                Text(player.video?.title ?? "")
                    .font(.system(size: 20, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .onTapGesture {
                        if let video = player.video {
                            UIApplication.shared.open(video.url)
                        }
                    }
                subscriptionTitle
            }
            .padding(.vertical)
            ZStack {
                if let video = player.video {
                    YoutubeWebViewPlayer(video: video,
                                         playbackSpeed: $player.playbackSpeed,
                                         onVideoEnded: handleVideoEnded
                    )
                } else {
                    Rectangle()
                        .fill(Color.backgroundColor)
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .frame(maxWidth: .infinity)

            VStack {
                SpeedControlView(selectedSpeed: $player.playbackSpeed)
                HStack {
                    customSettingsButton
                    Spacer()
                    watchedButton
                    Spacer()
                    continuousPlayButton
                }
                .padding(.horizontal, 5)
            }
            Spacer()
            ChapterMiniControlView()
            playButton
            Spacer()
            Button {
                setShowMenu()
            } label: {
                VStack {
                    Image(systemName: "chevron.up")
                    Text("showMenu")
                        .padding(.bottom, 3)
                }
                .padding(.horizontal, 2)
            }
            .buttonStyle(CapsuleButtonStyle())
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .updating($dragState) { value, state, _ in
                    state = value.translation.height
                    if state < -30 {
                        setShowMenu()
                    }
                }
        )
        .onChange(of: continuousPlay, { _, newValue in
            continuousPlayWorkaround = newValue
        })
        .onChange(of: player.video?.subscription) {
            // workaround to update ui, doesn't work without
        }
    }

    var watchedButton: some View {
        Button {
            markVideoWatched()
        } label: {
            Text("mark\nwatched")
        }
        .modifier(OutlineToggleModifier(isOn: player.isConsideredWatched))
    }

    var customSettingsButton: some View {
        Toggle(isOn: Binding(get: {
            player.video?.subscription?.customSpeedSetting != nil
        }, set: { value in
            player.video?.subscription?.customSpeedSetting = value ? playbackSpeed : nil
        })) {
            Text("custom\nsettings")
                .fontWeight(.medium)
        }
        .toggleStyle(OutlineToggleStyle())
        .disabled(player.video?.subscription == nil)
    }

    var continuousPlayButton: some View {
        Toggle(isOn: $continuousPlay) {
            Text("continuous\nplay")
                .fontWeight(.medium)
        }
        .toggleStyle(OutlineToggleStyle())
    }

    var subscriptionTitle: some View {
        HStack {
            Text(player.video?.subscription?.title ?? "–")
                .textCase(.uppercase)
            if let icon = subscribeManager.getSubscriptionSystemName(video: player.video) {
                Image(systemName: icon)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, options: .repeating, isActive: subscribeManager.isLoading)
            }
        }
        .foregroundColor(.teal)
        .onTapGesture {
            if let sub = player.video?.subscription {
                navManager.pushSubscription(sub)
                setShowMenu()
            }
        }
        .contextMenu {
            let isSubscribed = subscribeManager.isSubscribed(video: player.video)
            Button {
                withAnimation {
                    subscribeManager.handleSubscription(
                        video: player.video,
                        container: modelContext.container)
                }
            } label: {
                Text(isSubscribed ? "unsubscribe" : "subscribe")
            }
            .disabled(subscribeManager.isLoading)
        }
    }

    var playButton: some View {
        Button {
            player.isPlaying.toggle()
        } label: {
            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .accentColor(.myAccentColor)
                .contentTransition(.symbolEffect(.replace, options: .speed(7)))
        }
        .padding(20)
    }

    func markVideoWatched() {
        if let video = player.video {
            player.isPlaying = false
            setShowMenu()
            setNextVideo()
            VideoService.markVideoWatched(
                video, modelContext: modelContext
            )
        }
    }

    func handleVideoEnded() {
        guard continuousPlayWorkaround else {
            return
        }
        if let video = player.video {
            VideoService.markVideoWatched(
                video, modelContext: modelContext
            )
        }
        setNextVideo()
        player.isPlaying = true
    }

    func setShowMenu() {
        player.updateElapsedTime()
        showMenu = true
    }

    func setNextVideo() {
        guard let next = VideoService.getNextVideoInQueue(modelContext) else {
            print("no next video found")
            return
        }
        print("next", next.title)
        player.video = next
    }
}

#Preview {
    VideoPlayer(showMenu: .constant(false))
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(Alerter())
        .environment(PlayerManager.getDummy())
}
