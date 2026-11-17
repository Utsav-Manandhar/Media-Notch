import Foundation

struct Track: Equatable {
    var title: String
    var artist: String
    var artwork: URL?
    var isPlaying: Bool
    var duration: TimeInterval = 0
    /// Playback position in seconds, as it was at `fetchedAt`.
    var position: TimeInterval = 0
    var fetchedAt = Date.distantPast

    static let separator = "\u{1F}"

    /// Same song, whatever the playback state. Used to decide when to reload lyrics.
    var id: String { title + Track.separator + artist }

    /// Parses the output of `SpotifyScript.fetch`. Nil when nothing is loaded.
    static func parse(_ raw: String, now: Date = Date()) -> Track? {
        let fields = raw.components(separatedBy: separator)
        guard fields.count == 6 else { return nil }
        // AppleScript writes decimals with the system locale, so "12,5" is possible.
        let position = Double(fields[4].replacingOccurrences(of: ",", with: ".")) ?? 0
        return Track(title: fields[0], artist: fields[1],
                     artwork: URL(string: fields[2]), isPlaying: fields[3] == "playing",
                     duration: (Double(fields[5]) ?? 0) / 1000, position: position, fetchedAt: now)
    }

    /// Position now, counted forward from the last fetch while playing.
    func position(at date: Date) -> TimeInterval {
        let elapsed = isPlaying ? date.timeIntervalSince(fetchedAt) : 0
        return min(duration, max(0, position + elapsed))
    }
}

enum SpotifyScript {
    // The "is running" guard stops the script from launching Spotify.
    static let fetch = """
        if application "Spotify" is running then
            set s to character id 31
            tell application "Spotify"
                if player state is stopped then return ""
                return (name of current track) & s & (artist of current track) & s & (artwork url of current track) & s & (player state as text) & s & (player position) & s & (duration of current track)
            end tell
        end if
        return ""
        """
    static let playPause = "tell application \"Spotify\" to playpause"
    static let next = "tell application \"Spotify\" to next track"
    static let previous = "tell application \"Spotify\" to previous track"
    static func seek(to seconds: TimeInterval) -> String {
        // Whole seconds: AppleScript source would misread a decimal comma or point by locale.
        "tell application \"Spotify\" to set player position to \(Int(seconds))"
    }
}

final class NowPlaying: ObservableObject {
    @Published private(set) var track: Track?
    private let run: (String) -> String?

    /// `run` executes an AppleScript and returns its text result.
    init(run: @escaping (String) -> String?) {
        self.run = run
    }

    func refresh() {
        track = run(SpotifyScript.fetch).flatMap { Track.parse($0) }
    }

    func send(_ script: String) {
        _ = run(script)
    }

    func seek(to seconds: TimeInterval) {
        send(SpotifyScript.seek(to: seconds))
        refresh()
    }
}
