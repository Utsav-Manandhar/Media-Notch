import Foundation

struct Lyrics: Equatable {
    struct Line: Equatable {
        var time: TimeInterval
        var text: String
    }

    /// Timed lines, sorted by time.
    var synced: [Line] = []

    /// Parses LRC text: one "[mm:ss.xx] words" per line. Lines without a time tag are dropped.
    static func parseLRC(_ lrc: String) -> [Line] {
        lrc.split(whereSeparator: \.isNewline).compactMap { raw in
            guard let m = raw.firstMatch(of: #/^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/#),
                  let minutes = Double(m.1), let seconds = Double(m.2) else { return nil }
            return Line(time: minutes * 60 + seconds, text: m.3.trimmingCharacters(in: .whitespaces))
        }
        .sorted { $0.time < $1.time }
    }

    /// Index of the line being sung at `time`. Nil before the first line.
    func currentIndex(at time: TimeInterval) -> Int? {
        synced.lastIndex { $0.time <= time }
    }
}

/// One search result from lrclib.net.
struct LyricsCandidate: Decodable {
    var duration: Double
    var syncedLyrics: String?

    /// Picks timed lyrics for the same recording (length within 3 s). Untimed lyrics are ignored.
    static func pick(from candidates: [LyricsCandidate], duration: TimeInterval) -> Lyrics? {
        candidates.lazy
            .filter { abs($0.duration - duration) <= 3 }
            .compactMap(\.syncedLyrics)
            .map { Lyrics(synced: Lyrics.parseLRC($0)) }
            .first { !$0.synced.isEmpty }
    }
}

/// Looks the song up on lrclib.net (free, no key). Sends only the title and artist.
func fetchLyrics(for track: Track) async -> Lyrics? {
    var url = URLComponents(string: "https://lrclib.net/api/search")!
    url.queryItems = [URLQueryItem(name: "track_name", value: track.title),
                      URLQueryItem(name: "artist_name", value: track.artist)]
    var request = URLRequest(url: url.url!)
    request.setValue("Media Notch (personal macOS app)", forHTTPHeaderField: "User-Agent")
    guard let (data, _) = try? await URLSession.shared.data(for: request),
          let candidates = try? JSONDecoder().decode([LyricsCandidate].self, from: data) else { return nil }
    return LyricsCandidate.pick(from: candidates, duration: track.duration)
}
