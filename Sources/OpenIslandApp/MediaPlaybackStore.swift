import Observation

@MainActor
@Observable
final class MediaPlaybackStore {
    private let provider: AppleMusicProvider

    private(set) var playback: AppleMusicPlaybackInfo?

    init(provider: AppleMusicProvider = AppleMusicProvider()) {
        self.provider = provider
        provider.onUpdate = { [weak self] playback in
            self?.playback = playback
        }
    }

    func start() {
        provider.start()
    }

    func stop() {
        provider.stop()
        playback = nil
    }
}
