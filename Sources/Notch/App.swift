import AppKit
import SwiftUI

/// Runs AppleScript. Compiled scripts are kept, so the ones used on every hover are compiled once.
final class AppleScriptRunner {
    private let compiled = NSCache<NSString, NSAppleScript>()

    init() {
        compiled.countLimit = 8 // seek scripts differ every time; don't keep them all
    }

    func run(_ source: String) -> String? {
        let script = compiled.object(forKey: source as NSString) ?? NSAppleScript(source: source)
        guard let script else { return nil }
        compiled.setObject(script, forKey: source as NSString)
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error { NSLog("AppleScript failed: %@", error) } // -1743 = Spotify permission denied
        return result.stringValue
    }
}

extension NSScreen {
    /// Zero when this screen has no notch.
    var notchSize: CGSize {
        guard safeAreaInsets.top > 0, let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else { return .zero }
        return CGSize(width: frame.width - left.width - right.width, height: safeAreaInsets.top)
    }
}

/// One island on one screen: its window, its open/closed state and its hover handling.
final class Island: NSObject {
    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
    private let state = NotchState()
    private let player: NowPlaying
    private let layout: NotchLayout
    private let screenFrame: CGRect

    init(screen: NSScreen, player: NowPlaying, fetchLyrics: @escaping (Track) async -> Lyrics?,
         albumAccent: @escaping (URL) async -> Color?, openSettings: @escaping () -> Void) {
        self.player = player
        layout = NotchLayout(notch: screen.notchSize)
        screenFrame = screen.frame
        super.init()

        panel.level = .statusBar // above the menu bar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        // Set explicitly so the invisible hover strip on notch-less screens still gets the mouse;
        // by default macOS lets the mouse fall through transparent windows.
        panel.ignoresMouseEvents = false

        let host = NSHostingView(rootView: NotchView(player: player, state: state, layout: layout,
                                                     fetchLyrics: fetchLyrics, albumAccent: albumAccent,
                                                     openSettings: openSettings))
        host.sizingOptions = [] // we set the window frame ourselves
        // The window is exactly the island, so hovering the window is hovering the island.
        host.addTrackingArea(NSTrackingArea(rect: .zero,
                                            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                            owner: self))
        panel.contentView = host
        panel.setFrame(layout.frame(expanded: false, in: screenFrame), display: true)
        panel.orderFrontRegardless()
    }

    func close() {
        panel.close()
    }

    @objc(mouseEntered:) func mouseEntered(with event: NSEvent) {
        panel.setFrame(layout.frame(expanded: true, in: screenFrame), display: true)
        player.refresh() // resync the progress bar
        state.expanded = true
    }

    @objc(mouseExited:) func mouseExited(with event: NSEvent) {
        state.expanded = false
        // Shrink the window only after the collapse animation, so it isn't cut off.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [self] in
            if !state.expanded {
                panel.setFrame(layout.frame(expanded: false, in: screenFrame), display: true)
            }
        }
    }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let player = NowPlaying(run: AppleScriptRunner().run)
    private var islands: [Island] = []
    // Shared by all islands, so each song costs one lyrics request and one cover download.
    private let lyrics = Latest<String, Lyrics?>()
    private let accents = Latest<URL, Color?>()

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // no Dock icon
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        placeIslands()

        // Spotify posts this on every play, pause and track change, so no polling is needed.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil, queue: .main
        ) { [player] _ in player.refresh() }
        // Fires when a monitor is plugged in, unplugged or rearranged.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.placeIslands() }
        player.refresh()
    }

    /// One island per screen. On screens without a notch it stays hidden until the top edge is hovered.
    private func placeIslands() {
        islands.forEach { $0.close() }
        islands = NSScreen.screens.map { screen in
            Island(screen: screen, player: player,
                   fetchLyrics: { [lyrics] track in await lyrics.value(for: track.id) { await fetchLyrics(for: track) } },
                   albumAccent: { [accents] url in await accents.value(for: url) { await albumAccent(from: url) } },
                   openSettings: { [unowned self] in openSettings() })
        }
    }

    private lazy var settingsWindow: NSWindow = {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        window.title = "Media Notch Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }()

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true) // we have no Dock icon, so bring the window forward ourselves
        settingsWindow.makeKeyAndOrderFront(nil)
    }
}
