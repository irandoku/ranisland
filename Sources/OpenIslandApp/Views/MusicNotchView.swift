import AppKit
import SwiftUI

struct MusicNotchView: View {
    let playback: AppleMusicPlaybackInfo
    let onPrevious: () -> Void
    let onTogglePlayback: () -> Void
    let onNext: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    artworkView

                    VStack(alignment: .leading, spacing: 3) {
                        Text(playback.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                        Text([playback.artist, playback.album]
                            .filter { !$0.isEmpty }
                            .joined(separator: " · "))
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                if playback.duration > 0 {
                    ProgressView(value: progress(at: context.date))
                        .tint(.white.opacity(0.72))
                        .accessibilityLabel("Music progress")
                }

                HStack(spacing: 18) {
                    controlButton("backward.fill", label: "Previous track", action: onPrevious)
                    controlButton(
                        playback.isPlaying ? "pause.fill" : "play.fill",
                        label: playback.isPlaying ? "Pause" : "Play",
                        action: onTogglePlayback
                    )
                    controlButton("forward.fill", label: "Next track", action: onNext)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Now playing \(playback.title)")
        }
    }

    private func progress(at date: Date) -> Double {
        guard playback.duration > 0 else { return 0 }
        let elapsed = playback.isPlaying
            ? max(0, date.timeIntervalSince(playback.observedAt))
            : 0
        return min(1, (playback.position + elapsed) / playback.duration)
    }

    private func controlButton(
        _ systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artworkData = playback.artworkData,
           let artwork = NSImage(data: artworkData) {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: playback.isPlaying ? "music.note" : "pause.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
