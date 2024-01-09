//
//  VideoPlayer.swift
//  Unwatched
//

import SwiftUI

struct VideoPlayer: View {
    @Environment(\.dismiss) var dismiss
    @Environment(NavigationManager.self) private var navManager

    @Bindable var video: Video
    var markVideoWatched: () -> Void
    @State private var isCustomSetting: Bool = false
    @AppStorage("playbackSpeed") var playbackSpeed: Double = 1.0

    func setPlaybackSpeed(_ value: Double) {
        if video.subscription?.customSpeedSetting != nil {
            video.subscription?.customSpeedSetting = value
        } else {
            playbackSpeed = value
        }
    }

    func getPlaybackSpeed() -> Double {
        video.subscription?.customSpeedSetting ?? playbackSpeed
    }

    var watchedButton: some View {
        Button {
            markVideoWatched()
            dismiss()
        } label: {
            Text("Mark Watched")
                .bold()
                .padding(.horizontal, 25)
                .padding(.vertical, 15)
        }
        .background(Color.accentColor)
        .foregroundColor(.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
    }

    var customSettingsButton: some View {
        Toggle(isOn: Binding(get: {
            video.subscription?.customSpeedSetting != nil
        }, set: { value in
            video.subscription?.customSpeedSetting = value ? playbackSpeed : nil
        })) {
            Text("Custom settings for this feed")
                .fontWeight(.medium)
        }
        .toggleStyle(OutlineToggleStyle())
        .disabled(video.subscription == nil)
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 10) {
                Text(video.title)
                    .font(.system(size: 20, weight: .heavy))
                    .multilineTextAlignment(.center)
                Text(video.subscription?.title ?? "no subscription found")
                    .textCase(.uppercase)
                    .foregroundColor(.teal)
                    .onTapGesture {
                        if let sub = video.subscription {
                            navManager.pushSubscription(sub)
                            dismiss()
                        }
                    }
            }
            .padding(.vertical)

            WebViewWrapper(videoID: video.youtubeId,
                           playbackSpeed: Binding(get: getPlaybackSpeed, set: setPlaybackSpeed)
            )
            .aspectRatio(16/9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack {
                SpeedControlView(selectedSpeed: Binding(
                                    get: getPlaybackSpeed,
                                    set: setPlaybackSpeed)
                )
                customSettingsButton
            }
            .padding(.vertical)
            Spacer()

            watchedButton
        }
        .padding(.top, 25)
        .padding(.horizontal)
    }
}

#Preview {
    VideoPlayer(video: Video.dummy, markVideoWatched: {})
}
