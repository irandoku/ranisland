import AppKit
import SwiftUI

struct MusicArtworkThumbnail: View {
    let playback: AppleMusicPlaybackInfo
    let size: CGFloat

    var body: some View {
        if let artworkData = playback.artworkData,
           let artwork = NSImage(data: artworkData) {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
        } else {
            Image(systemName: playback.isPlaying ? "music.note" : "play.fill")
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: size, height: size)
                .background(
                    .white.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: size * 0.25)
                )
        }
    }
}

struct MusicMiniPlayer: View {
    static let preferredHeight: CGFloat = 58
    private static let contentMaxWidth: CGFloat = 420

    let playback: AppleMusicPlaybackInfo
    let onOpen: () -> Void
    let onTogglePlayback: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    MusicArtworkThumbnail(playback: playback, size: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(playback.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(1)
                        Text(playback.artist.isEmpty ? "Apple Music" : playback.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 300, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Music controls")

            Spacer(minLength: 0)

            Button(action: onTogglePlayback) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
        }
        .frame(maxWidth: Self.contentMaxWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: Self.preferredHeight, alignment: .center)
        .frame(height: Self.preferredHeight)
        .background(.white.opacity(0.035))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.055))
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Music mini-player")
    }
}

struct MusicNotchView: View {
    let playback: AppleMusicPlaybackInfo
    let onPrevious: () -> Void
    let onTogglePlayback: () -> Void
    let onNext: () -> Void

    static let preferredHeight: CGFloat = 170
    private static let contentMaxWidth: CGFloat = 380

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .center, spacing: 14) {
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
                            .frame(maxWidth: 320, alignment: .leading)
                    }
                }
                .frame(maxWidth: Self.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)

                if playback.duration > 0 {
                    ProgressView(value: progress(at: context.date))
                        .tint(.white.opacity(0.72))
                        .frame(maxWidth: Self.contentMaxWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityLabel("Music progress")
                }

                HStack {
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
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Now playing \(playback.title)")
        }
        .frame(maxWidth: .infinity)
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
        MusicArtworkThumbnail(playback: playback, size: 32)
    }
}
