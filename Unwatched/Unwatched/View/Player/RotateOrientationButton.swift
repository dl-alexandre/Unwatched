//
//  RotateOrientationButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct RotateOrientationButton: View {
    @State var hapticToggle = false
    var body: some View {
        Button {
            hapticToggle.toggle()
            OrientationManager.changeOrientation(to: .landscapeRight)
        } label: {
            Image(systemName: Const.enableFullscreenSF)
                .playerToggleModifier(isOn: false, isSmall: true)
        }
        .help("fullscreenRight")
        .accessibilityLabel("fullscreenRight")
        .padding(2)
        .contextMenu {
            Button {
                OrientationManager.changeOrientation(to: .landscapeLeft)
            } label: {
                Label("fullscreenLeft", systemImage: Const.enableFullscreenSF)
            }
        }
        .padding(-2)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }
}

struct HideControlsButton: View {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false
    var textOnly: Bool = false
    var enableEscapeButton: Bool = true

    var body: some View {
        Button {
            handlePress()
        } label: {
            if textOnly {
                Text("toggleFullscreen")
            } else {
                Image(systemName: hideControlsFullscreen
                        ? Const.disableFullscreenSF
                        : Const.enableFullscreenSF)
                    .playerToggleModifier(isOn: hideControlsFullscreen)
            }
        }
        .help("toggleFullscreen")
        .background {
            // workaround: enable esc press to exit video
            if enableEscapeButton {
                Button {
                    handlePress()
                } label: { }
                .keyboardShortcut(hideControlsFullscreen ? .escape : "v", modifiers: [])
            }
        }
    }

    func handlePress() {
        withAnimation {
            hideControlsFullscreen.toggle()
        }
    }
}
