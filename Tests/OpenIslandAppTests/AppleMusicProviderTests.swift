import Foundation
import Testing
@testable import OpenIslandApp

struct AppleMusicProviderTests {
    @Test
    func parsesPlaybackInfo() {
        let raw = "playing\u{1F}Track title\u{1F}Artist\u{1F}Album\u{1F}12.5\u{1F}240\u{1F}YXJ0"

        let info = AppleMusicPlaybackInfo.parse(raw)

        #expect(info?.state == .playing)
        #expect(info?.title == "Track title")
        #expect(info?.artist == "Artist")
        #expect(info?.album == "Album")
        #expect(info?.position == 12.5)
        #expect(info?.duration == 240)
        #expect(info?.artworkData == Data("art".utf8))
    }

    @Test
    func rejectsEmptyTrackAndMalformedOutput() {
        #expect(AppleMusicPlaybackInfo.parse("") == nil)
        #expect(AppleMusicPlaybackInfo.parse("paused\u{1F}\u{1F}Artist\u{1F}Album\u{1F}0\u{1F}240") == nil)
    }
}
