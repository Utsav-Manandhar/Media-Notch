import Foundation

struct NotchLayout {
    /// Size of the physical notch. Zero on a screen without one.
    let notch: CGSize

    var hasNotch: Bool { notch.height > 0 }

    /// The island as drawn when closed: the notch plus one square "wing" on each side for artwork
    /// and the playing icon. On a screen without a notch nothing is drawn (height 0).
    var collapsed: CGSize {
        hasNotch ? CGSize(width: notch.width + 2 * notch.height, height: notch.height)
                 : CGSize(width: 260, height: 0)
    }

    /// Where content starts in the open island. The physical notch hides everything above its bottom edge.
    var contentTop: CGFloat { hasNotch ? notch.height + 2 : 10 }

    /// The open island. The window always uses the tall (lyrics) size; the island is drawn shorter without lyrics.
    func expanded(lyrics: Bool = true) -> CGSize {
        CGSize(width: max(400, collapsed.width), height: contentTop + (lyrics ? 113 : 88))
    }

    /// Window size. Closed on a screen without a notch, it is a thin invisible strip
    /// along the top edge whose only job is to catch the hover.
    func windowSize(expanded isExpanded: Bool) -> CGSize {
        isExpanded ? expanded() : CGSize(width: collapsed.width, height: max(collapsed.height, 3))
    }

    /// Window frame pinned to the top centre of `screen` (AppKit coordinates, origin bottom-left).
    func frame(expanded isExpanded: Bool, in screen: CGRect) -> CGRect {
        let s = windowSize(expanded: isExpanded)
        return CGRect(x: screen.midX - s.width / 2, y: screen.maxY - s.height, width: s.width, height: s.height)
    }
}
