#if os(iOS)
import SwiftUI
import UIKit

/// Scrollable bar with extra keys (Esc, Tab, Ctrl, arrows, etc.)
struct ExtraKeysBar: View {
    let onKey: (ExtraKey) -> Void

    enum ExtraKey: String, CaseIterable {
        case esc = "Esc"
        case tab = "Tab"
        case ctrl = "Ctrl"
        case alt = "Alt"
        case up = "↑"
        case down = "↓"
        case left = "←"
        case right = "→"
        case pipe = "|"
        case tilde = "~"
        case dash = "-"
        case slash = "/"
        case backslash = "\\"

        var data: Data {
            switch self {
            case .esc: Data([0x1B])
            case .tab: Data([0x09])
            case .ctrl: Data()
            case .alt: Data()
            case .up: Data([0x1B, 0x5B, 0x41])
            case .down: Data([0x1B, 0x5B, 0x42])
            case .right: Data([0x1B, 0x5B, 0x43])
            case .left: Data([0x1B, 0x5B, 0x44])
            case .pipe: Data("|".utf8)
            case .tilde: Data("~".utf8)
            case .dash: Data("-".utf8)
            case .slash: Data("/".utf8)
            case .backslash: Data("\\".utf8)
            }
        }

        var isModifier: Bool {
            self == .ctrl || self == .alt
        }
    }

    @State private var ctrlActive = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ExtraKey.allCases, id: \.self) { key in
                    Button {
                        if key == .ctrl {
                            ctrlActive.toggle()
                        } else {
                            onKey(key)
                            ctrlActive = false
                        }
                    } label: {
                        Text(key.rawValue)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(key == .ctrl && ctrlActive ? .blue : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(key == .ctrl && ctrlActive ? Color.blue.opacity(0.2) : Color(UIColor.systemGray5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(Color(UIColor.systemGray6))
    }
}
#endif
