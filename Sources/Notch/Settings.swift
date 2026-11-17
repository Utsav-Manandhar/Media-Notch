import AppKit
import SwiftUI

/// The accent colour, stored in UserDefaults as "#RRGGBB".
enum Accent {
    static let key = "accentHex"
    static let matchAlbumKey = "matchAlbum"
    static let presets: [(name: String, hex: String)] = [
        ("Lime", "#9DFF5C"), ("Aqua", "#3DF5FF"), ("Pink", "#FF4FD8"),
        ("Purple", "#B26BFF"), ("Orange", "#FF9F3D"), ("Yellow", "#FFF04D"),
    ]
    static let defaultHex = presets[0].hex
}

extension Color {
    /// Falls back to the default accent when `hex` is not "#RRGGBB".
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = digits.count == 6 ? UInt32(digits, radix: 16) : nil
        let v = value ?? UInt32(Accent.defaultHex.dropFirst(), radix: 16)!
        self.init(.sRGB, red: Double(v >> 16 & 0xFF) / 255, green: Double(v >> 8 & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    var hex: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return Accent.defaultHex }
        return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
}

struct SettingsView: View {
    @AppStorage(Accent.key) private var accentHex = Accent.defaultHex
    @AppStorage(Accent.matchAlbumKey) private var matchAlbum = false

    var body: some View {
        Form {
            Section {
                Toggle("Match album cover", isOn: $matchAlbum)
            } footer: {
                Text("Uses the cover's main colour. Black, grey and white covers give white. The colour below is used until the cover loads.")
            }
            Section("Accent colour") {
                HStack(spacing: 14) {
                    ForEach(Accent.presets, id: \.hex) { preset in
                        let color = Color(hex: preset.hex)
                        Button { accentHex = preset.hex } label: {
                            Circle().fill(color)
                                .frame(width: 28, height: 28)
                                .shadow(color: color.opacity(0.8), radius: 6)
                                .overlay { Circle().strokeBorder(.primary, lineWidth: accentHex == preset.hex ? 2.5 : 0) }
                        }
                        .buttonStyle(.plain)
                        .help(preset.name)
                        .accessibilityLabel(preset.name)
                        .accessibilityAddTraits(accentHex == preset.hex ? .isSelected : [])
                    }
                }
                .frame(maxWidth: .infinity)
                // Opens the system colour panel, which has the colour wheel.
                ColorPicker("Custom colour", selection: Binding(get: { Color(hex: accentHex) },
                                                                set: { accentHex = $0.hex }),
                            supportsOpacity: false)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize()
    }
}
