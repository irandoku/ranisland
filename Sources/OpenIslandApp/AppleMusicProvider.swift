import AppKit
import Foundation

struct AppleMusicPlaybackInfo: Equatable, Sendable {
    enum PlayerState: String, Sendable {
        case playing
        case paused
        case stopped
        case unknown
    }

    let state: PlayerState
    let title: String
    let artist: String
    let album: String
    let position: TimeInterval
    let duration: TimeInterval
    let artworkData: Data?
    let observedAt: Date

    var isPlaying: Bool { state == .playing }

    var isPresentable: Bool { state == .playing || state == .paused }

    func replacingArtwork(with artworkData: Data) -> Self {
        Self(
            state: state,
            title: title,
            artist: artist,
            album: album,
            position: position,
            duration: duration,
            artworkData: artworkData,
            observedAt: observedAt
        )
    }

    static func parse(_ output: String) -> Self? {
        let fields = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\u{1F}", omittingEmptySubsequences: false)
            .map(String.init)

        guard fields.count >= 6 else { return nil }
        let title = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        return Self(
            state: PlayerState(rawValue: fields[0].lowercased()) ?? .unknown,
            title: title,
            artist: fields[2].trimmingCharacters(in: .whitespacesAndNewlines),
            album: fields[3].trimmingCharacters(in: .whitespacesAndNewlines),
            position: max(0, Double(fields[4]) ?? 0),
            duration: max(0, Double(fields[5]) ?? 0),
            artworkData: fields.count > 6 && !fields[6].isEmpty
                ? Data(base64Encoded: fields[6], options: .ignoreUnknownCharacters)
                : nil,
            observedAt: .now
        )
    }
}

struct MediaRemoteArtworkPayload: Decodable, Equatable {
    let title: String?
    let artist: String?
    let album: String?
    let artworkData: String?

    var decodedArtwork: Data? {
        guard let artworkData, !artworkData.isEmpty else { return nil }
        return Data(base64Encoded: artworkData, options: .ignoreUnknownCharacters)
    }

    static func parse(_ output: Data) -> Self? {
        try? JSONDecoder().decode(Self.self, from: output)
    }
}

@MainActor
final class AppleMusicProvider {
    typealias CommandRunner = @Sendable () -> String?
    typealias RunningCheck = @Sendable () -> Bool
    typealias ActionRunner = @Sendable (String) -> Void
    typealias ArtworkRunner = @Sendable (AppleMusicPlaybackInfo) -> Data?

    enum ControlAction: String, Sendable {
        case previous = "previous track"
        case togglePlayback = "playpause"
        case next = "next track"
    }

    private static let notificationName = Notification.Name("com.apple.Music.playerInfo")

    private let commandRunner: CommandRunner
    private let runningCheck: RunningCheck
    private let actionRunner: ActionRunner
    private let artworkRunner: ArtworkRunner
    private var notificationToken: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?

    var onUpdate: (@MainActor (AppleMusicPlaybackInfo?) -> Void)?

    init(
        commandRunner: CommandRunner? = nil,
        runningCheck: RunningCheck? = nil,
        actionRunner: ActionRunner? = nil,
        artworkRunner: ArtworkRunner? = nil
    ) {
        self.commandRunner = commandRunner ?? AppleMusicProvider.fetchPlaybackInfo
        self.runningCheck = runningCheck ?? AppleMusicProvider.isMusicRunning
        self.actionRunner = actionRunner ?? AppleMusicProvider.runControlScript
        self.artworkRunner = artworkRunner ?? AppleMusicProvider.fetchMediaRemoteArtwork
    }

    func start() {
        guard notificationToken == nil else { return }

        notificationToken = DistributedNotificationCenter.default().addObserver(
            forName: Self.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        refresh()
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        if let notificationToken {
            DistributedNotificationCenter.default().removeObserver(notificationToken)
            self.notificationToken = nil
        }
    }

    func refresh() {
        guard runningCheck() else {
            onUpdate?(nil)
            return
        }

        refreshTask?.cancel()
        let commandRunner = self.commandRunner
        let artworkRunner = self.artworkRunner
        let apply: @MainActor @Sendable (AppleMusicPlaybackInfo?) -> Void = { [weak self] playback in
            self?.onUpdate?(playback)
        }
        refreshTask = Task.detached {
            let playback = commandRunner().flatMap(AppleMusicPlaybackInfo.parse).map { playback in
                guard playback.artworkData == nil,
                      let artworkData = artworkRunner(playback)
                else {
                    return playback
                }
                return playback.replacingArtwork(with: artworkData)
            }
            guard !Task.isCancelled else { return }
            await apply(playback)
        }
    }

    func perform(_ action: ControlAction) {
        guard runningCheck() else { return }
        actionRunner(action.rawValue)
    }

    nonisolated private static func isMusicRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
    }

    nonisolated private static func fetchPlaybackInfo() -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    nonisolated private static func runControlScript(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "tell application \"Music\" to \(command)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        process.waitUntilExit()
    }

    nonisolated private static func fetchMediaRemoteArtwork(
        for playback: AppleMusicPlaybackInfo
    ) -> Data? {
        guard let resourceURL = Bundle.appResources.resourceURL else {
            return nil
        }
        let scriptURL = resourceURL.appendingPathComponent("mediaremote-artwork.pl")
        let frameworkURL = resourceURL.appendingPathComponent("MediaRemoteAdapter")
        guard FileManager.default.isReadableFile(atPath: scriptURL.path),
              FileManager.default.isReadableFile(atPath: frameworkURL.path)
        else {
            return nil
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkURL.path]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let payload = MediaRemoteArtworkPayload.parse(data),
                  payload.title == playback.title,
                  let artwork = payload.decodedArtwork,
                  !artwork.isEmpty
            else {
                return nil
            }

            if let artist = payload.artist,
               !artist.isEmpty,
               !playback.artist.isEmpty,
               artist != playback.artist
            {
                return nil
            }
            return artwork
        } catch {
            return nil
        }
    }

    nonisolated private static let appleScript = """
    tell application "Music"
        set currentTrack to current track
        set separator to character id 31
        set artworkPath to ""
        set artworkData to missing value
        set artworkBase64 to ""
        try
            set artworkPath to do shell script "/usr/bin/mktemp /tmp/openisland-artwork.XXXXXX"
            set artworkFile to open for access (POSIX file artworkPath) with write permission
            set artworkData to get data of artwork 1 of currentTrack
            write artworkData to artworkFile
            close access artworkFile
            set artworkBase64 to do shell script "/usr/bin/base64 -b 0 -i " & quoted form of artworkPath
            do shell script "/bin/rm -f " & quoted form of artworkPath
        on error
            try
                close access artworkFile
            end try
            if artworkPath is not "" then
                try
                    do shell script "/bin/rm -f " & quoted form of artworkPath
                end try
            end if
        end try
        return (player state as text) & separator & (name of currentTrack as text) & separator & (artist of currentTrack as text) & separator & (album of currentTrack as text) & separator & (player position as text) & separator & (duration of currentTrack as text) & separator & artworkBase64
    end tell
    """
}
