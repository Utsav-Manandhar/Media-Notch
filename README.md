# Media Notch

A small Dynamic Island for the Mac notch. Hover the notch to see the current Spotify track,
play, pause, skip, seek and read timed lyrics.

    make run    # build, install to /Applications and launch
    make test

- On first launch macOS asks to let Media Notch control Spotify. Allow it.
- The gear in the open island (or right-click) opens Settings: accent colour, or match the album cover.
- On a monitor without a notch the island is hidden; push the mouse against the top edge to open it.
- Lyrics come from lrclib.net. The song title and artist are sent there when the island is open.
- Right-click the island to quit. Start it again from Spotlight: Cmd-Space, "Media Notch".
