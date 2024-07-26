//
//  RotateOrientationButton.swift
//  Unwatched
//

import SwiftUI

struct RotateOrientationButton: View {
    var body: some View {
        Button {
            OrientationManager.changeOrientation(to: .landscapeRight)
        } label: {
            Image(systemName: Const.enableFullscreenSF)
                .outlineToggleModifier(isOn: false, isSmall: true)
        }
        .padding(2)
        .contextMenu {
            Button {
                OrientationManager.changeOrientation(to: .landscapeLeft)
            } label: {
                Label("fullscreenLeft", systemImage: "rectangle.landscape.rotate")
            }
        }
    }
}

struct HideControlsButton: View {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false

    var body: some View {
        Button {
            handlePress()
        } label: {
            Image(systemName: hideControlsFullscreen
                    ? Const.disableFullscreenSF
                    : Const.enableFullscreenSF)
                .outlineToggleModifier(isOn: hideControlsFullscreen)
        }
        .keyboardShortcut("f", modifiers: [])
        .background {
            // workaround: enable esc press to exit video
            Button {
                handlePress()
            } label: { }
            .keyboardShortcut(hideControlsFullscreen ? .escape : "v", modifiers: [])
        }
    }

    func handlePress() {
        withAnimation {
            hideControlsFullscreen.toggle()
        }
    }
}
