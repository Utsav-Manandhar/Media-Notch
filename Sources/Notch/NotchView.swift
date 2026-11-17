import SwiftUI

final class NotchState: ObservableObject {
    @Published var expanded = false
}

struct NotchView: View {
    @ObservedObject var player: NowPlaying
    @ObservedObject var state: NotchState
    let layout: NotchLayout
    let fetchLyrics: (Track) async -> Lyrics?
    let albumAccent: (URL) async -> Color?
    let openSettings: () -> Void

    @State private var lyrics: Lyrics?
    @State private var albumColor: Color?
    @AppStorage(Accent.key) private var accentHex = Accent.defaultHex
    @AppStorage(Accent.matchAlbumKey) private var matchAlbum = false
    private var glow: Color { (matchAlbum ? albumColor : nil) ?? Color(hex: accentHex) }

    var body: some View {
        let size = state.expanded
            ? layout.expanded(lyrics: lyrics != nil && player.track != nil) : layout.collapsed
        content
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .topTrailing) { if state.expanded { settingsButton } }
            .background(.black)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: state.expanded ? 22 : 10,
                                              bottomTrailingRadius: state.expanded ? 22 : 10))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state.expanded)
            .animation(.default, value: player.track?.id)
            .animation(.default, value: lyrics)
            // Lyrics are only looked up while the island is open.
            .task(id: state.expanded ? player.track?.id : nil) {
                if state.expanded, let track = player.track { lyrics = await fetchLyrics(track) }
            }
            .onChange(of: player.track?.id) { lyrics = nil }
            // Re-runs when the cover changes or the setting is switched.
            .task(id: matchAlbum ? player.track?.artwork : nil) {
                if matchAlbum, let url = player.track?.artwork { albumColor = await albumAccent(url) }
            }
            .animation(.easeInOut(duration: 0.4), value: glow)
            .environment(\.colorScheme, .dark)
            .contextMenu {
                Button("Settings…", action: openSettings)
                Button("Quit Media Notch") { NSApp.terminate(nil) }
            }
    }

    private var settingsButton: some View {
        Button(action: openSettings) {
            Image(systemName: "gearshape.fill").frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Settings")
        .padding(.top, layout.contentTop)
        .padding(.trailing, 12)
    }

    @ViewBuilder private var content: some View {
        if let track = player.track {
            if state.expanded { expandedContent(track) } else if layout.hasNotch { collapsedContent(track) }
        } else if state.expanded {
            Text("Nothing playing")
                .foregroundStyle(.secondary)
                .padding(.top, layout.contentTop)
        }
    }

    private func collapsedContent(_ track: Track) -> some View {
        HStack {
            artwork(track, size: layout.notch.height - 10)
            Spacer()
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative, isActive: track.isPlaying)
                .foregroundStyle(track.isPlaying ? AnyShapeStyle(glow) : AnyShapeStyle(.secondary))
                .accessibilityLabel(track.isPlaying ? "Playing" : "Paused")
        }
        .padding(.horizontal, 6)
    }

    // Header on the left (artwork, then "Title Artist" on one line), then the buttons, the bar, the lyrics.
    private func expandedContent(_ track: Track) -> some View {
        VStack(spacing: 5) {
            HStack {
                artwork(track, size: 28)
                Spacer(minLength: 0)
            }
            .overlay {
                (Text(track.title).bold() + Text("  " + track.artist).foregroundColor(.secondary))
                    .lineLimit(1)
                    .truncationMode(.tail) // long names end in "…"
                    .padding(.leading, 38) // clear of the artwork
                    .padding(.trailing, 24) // the gear ends 36 pt from the island edge; leave a ~6 pt gap
            }
            HStack(spacing: 30) {
                control("backward.fill", "Previous track", SpotifyScript.previous)
                control(track.isPlaying ? "pause.fill" : "play.fill",
                        track.isPlaying ? "Pause" : "Play", SpotifyScript.playPause)
                    .font(.title2)
                control("forward.fill", "Next track", SpotifyScript.next)
            }
            .font(.title3)
            .buttonStyle(GlowButtonStyle(color: glow))
            // Ticks twice a second while playing and not at all while paused.
            // The position is counted forward locally; Spotify is not asked again.
            TimelineView(.animation(minimumInterval: 0.5, paused: !track.isPlaying)) { context in
                let position = track.position(at: context.date)
                VStack(spacing: 5) {
                    ProgressBar(position: position, duration: track.duration, color: glow) { player.seek(to: $0) }
                    if let lyrics { lyricsView(lyrics, at: position) }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, layout.contentTop)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// One line: the lyric being sung, or the upcoming one (dimmed) during a gap.
    private func lyricsView(_ lyrics: Lyrics, at position: TimeInterval) -> some View {
        let current = lyrics.currentIndex(at: position)
        let sung = text(lyrics, current)
        return Text(sung.isEmpty ? text(lyrics, (current ?? -1) + 1) : sung)
            .font(.callout.weight(.semibold))
            .foregroundStyle(sung.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(glow))
            .shadow(color: glow.opacity(sung.isEmpty ? 0 : 0.5), radius: 6)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 20)
            .animation(.easeInOut(duration: 0.25), value: current)
    }

    private func text(_ lyrics: Lyrics, _ index: Int?) -> String {
        guard let index, lyrics.synced.indices.contains(index) else { return "" }
        return lyrics.synced[index].text
    }

    private func artwork(_ track: Track, size: CGFloat) -> some View {
        AsyncImage(url: track.artwork) { $0.resizable().aspectRatio(contentMode: .fill) }
            placeholder: { Color.gray.opacity(0.3) }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size / 5))
            .accessibilityHidden(true)
    }

    private func control(_ symbol: String, _ label: String, _ script: String) -> some View {
        Button { player.send(script) } label: {
            Image(systemName: symbol)
                .contentTransition(.symbolEffect(.replace)) // play and pause morph into each other
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}
