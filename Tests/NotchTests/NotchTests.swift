import SwiftUI
import XCTest
@testable import Notch

final class NotchTests: XCTestCase {
    func testParsesTrack() {
        let s = Track.separator
        let now = Date()
        let track = Track.parse("Song\(s)Artist\(s)https://i.scdn.co/image/abc\(s)playing\(s)12,5\(s)200000", now: now)
        XCTAssertEqual(track, Track(title: "Song", artist: "Artist",
                                    artwork: URL(string: "https://i.scdn.co/image/abc"), isPlaying: true,
                                    duration: 200, position: 12.5, fetchedAt: now))
        XCTAssertEqual(Track.parse("Song\(s)Artist\(s)\(s)paused\(s)1.5\(s)1000")?.isPlaying, false)
    }

    func testEmptyOutputMeansNoTrack() {
        XCTAssertNil(Track.parse(""))
    }

    func testRefreshUsesInjectedRunner() {
        let s = Track.separator
        let player = NowPlaying(run: { _ in "A\(s)B\(s)\(s)playing\(s)0\(s)1000" })
        player.refresh()
        XCTAssertEqual(player.track?.title, "A")
    }

    func testFrameIsPinnedTopCentre() {
        let layout = NotchLayout(notch: CGSize(width: 200, height: 32))
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        for expanded in [false, true] {
            let frame = layout.frame(expanded: expanded, in: screen)
            XCTAssertEqual(frame.midX, screen.midX)
            XCTAssertEqual(frame.maxY, screen.maxY)
        }
    }

    func testPositionCountsForwardOnlyWhilePlaying() {
        let t0 = Date()
        var track = Track(title: "", artist: "", isPlaying: true, duration: 100, position: 10, fetchedAt: t0)
        XCTAssertEqual(track.position(at: t0 + 5), 15)
        XCTAssertEqual(track.position(at: t0 + 500), 100) // never past the end
        track.isPlaying = false
        XCTAssertEqual(track.position(at: t0 + 5), 10)
    }

    func testParsesLRCAndFindsCurrentLine() {
        let lyrics = Lyrics(synced: Lyrics.parseLRC("[00:10.50] first\n[ar: someone]\n[01:02.00]second\n"))
        XCTAssertEqual(lyrics.synced, [.init(time: 10.5, text: "first"), .init(time: 62, text: "second")])
        XCTAssertNil(lyrics.currentIndex(at: 5))
        XCTAssertEqual(lyrics.currentIndex(at: 30), 0)
        XCTAssertEqual(lyrics.currentIndex(at: 62), 1)
    }

    func testPicksLyricsForSameLengthPreferringSynced() {
        let candidates = [
            LyricsCandidate(duration: 300, syncedLyrics: "[00:01.00] live"),
            LyricsCandidate(duration: 201, syncedLyrics: nil),
            LyricsCandidate(duration: 199, syncedLyrics: "[00:01.00] words"),
        ]
        XCTAssertEqual(LyricsCandidate.pick(from: candidates, duration: 200)?.synced.first?.text, "words")
        XCTAssertNil(LyricsCandidate.pick(from: candidates, duration: 50))
    }

    func testSeekRefreshesAndUsesWholeSeconds() {
        XCTAssertEqual(SpotifyScript.seek(to: 61.9), "tell application \"Spotify\" to set player position to 61")
        var scripts: [String] = []
        let player = NowPlaying(run: { scripts.append($0); return nil })
        player.seek(to: 30)
        XCTAssertEqual(scripts, [SpotifyScript.seek(to: 30), SpotifyScript.fetch])
    }

    func testAccentHexRoundTripsAndFallsBack() {
        XCTAssertEqual(Color(hex: "#3DF5FF").hex, "#3DF5FF")
        XCTAssertEqual(Color(hex: "nonsense").hex, Accent.defaultHex)
    }

    func testScreenWithoutNotchIsInvisibleUntilHovered() {
        let layout = NotchLayout(notch: .zero)
        XCTAssertEqual(layout.collapsed.height, 0) // nothing drawn
        XCTAssertEqual(layout.windowSize(expanded: false).height, 3) // thin hover strip
        XCTAssertLessThan(layout.contentTop, 16) // no empty strip reserved for a notch
        XCTAssertLessThan(layout.expanded().height, NotchLayout(notch: CGSize(width: 185, height: 32)).expanded().height)
    }

    func testAlbumColour() {
        typealias RGB = AlbumColor.RGB
        let black = RGB(r: 0.02, g: 0.02, b: 0.02), grey = RGB(r: 0.5, g: 0.5, b: 0.5)
        let red = RGB(r: 0.9, g: 0.1, b: 0.1), blue = RGB(r: 0.1, g: 0.2, b: 0.9)

        // Black and grey covers, and a black cover with a tiny coloured logo, give white.
        XCTAssertEqual(AlbumColor.accent(for: Array(repeating: black, count: 100)), AlbumColor.white)
        XCTAssertEqual(AlbumColor.accent(for: Array(repeating: grey, count: 100)), AlbumColor.white)
        XCTAssertEqual(AlbumColor.accent(for: Array(repeating: black, count: 98) + [red, red]), AlbumColor.white)
        XCTAssertEqual(AlbumColor.accent(for: []), AlbumColor.white)

        // The most common colour wins, at full brightness.
        let mostlyBlue = AlbumColor.accent(for: Array(repeating: blue, count: 60) + Array(repeating: red, count: 20)
            + Array(repeating: black, count: 20))
        XCTAssertEqual(mostlyBlue.hue, 0.65, accuracy: 0.03) // blue is around 0.65
        XCTAssertEqual(mostlyBlue.brightness, 1)
        let halfRed = AlbumColor.accent(for: Array(repeating: red, count: 50) + Array(repeating: black, count: 50))
        XCTAssertTrue(halfRed.hue < 0.03 || halfRed.hue > 0.97) // red is at 0 (and wraps at 1)
    }

    func testLatestSharesOneLoadPerKey() async {
        let latest = Latest<String, Int>()
        let loads = Counter()
        let load = { await loads.next() }
        let a = await latest.value(for: "song", load: load)
        let b = await latest.value(for: "song", load: load)
        let c = await latest.value(for: "other", load: load)
        XCTAssertEqual([a, b, c], [1, 1, 2])
    }
}

private actor Counter {
    private var count = 0
    func next() -> Int { count += 1; return count }
}
