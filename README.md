# Media Notch

A small Dynamic Island for the Mac notch. Hover the notch to see the current Spotify track,
then play, pause, skip, seek and read timed lyrics.

- Hover the notch (or the top edge of a monitor without one) to open the island.
- Click or drag the glowing progress bar to seek.
- Timed lyrics, one line at a time, when available.
- Accent colour: neon presets, a colour wheel, or match the album cover.
- One island per screen. On a monitor without a notch it stays hidden until you hover the top edge.

## Requirements

- macOS 14 or later
- Xcode command line tools (Swift 5.9+)
- Spotify desktop app

## Install

    make run    # build, install to /Applications and launch
    make test

Then start it any time with Spotlight: Cmd-Space, "Media Notch".

The app is ad-hoc signed, so macOS may ask for permission again after a rebuild.

## Permissions

On first launch macOS asks to let Media Notch control Spotify. Allow it. If you denied it,
re-enable it in System Settings, Privacy & Security, Automation.

## Settings

The gear in the open island (or right-click) opens Settings: accent colour, or match the album cover.
Right-click the island to quit.

## Privacy

Lyrics come from [lrclib.net](https://lrclib.net). The song title and artist are sent there
when the island is open. Nothing else leaves your Mac except the album cover download from Spotify.

## Limits

- Spotify only.
- No start at login.
- Not on the Mac App Store; it is built from source.

## Layout

    Sources/Notch/
      App.swift          app start, one Island (window + hover) per screen
      NotchView.swift    the island UI
      NotchLayout.swift  sizes and positions
      NowPlaying.swift   Spotify through AppleScript
      Lyrics.swift       lrclib lookup and timed-lyrics parsing
      AlbumColor.swift   picks an accent colour from cover art
      ProgressBar.swift  seekable bar and glow button style
      Settings.swift     settings window and colour helpers
