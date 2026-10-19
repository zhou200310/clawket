#if os(iOS)
import SwiftUI
import UIKit

/// Shared visual language for the native client: one soft canvas, one card
/// radius, one material for floating chrome. Kept deliberately small so every
/// surface in the app reads as the same product.
enum NativeTheme {
    static let cardCorner: CGFloat = 22
    static let bubbleCorner: CGFloat = 22
}

/// Calm backdrop: base surface with a single accent glow anchored top-trailing,
/// echoing the accent the user picked in settings.
struct NativeCanvas: View {
    @Environment(\.colorScheme) private var scheme
    var accent: Color = .accentColor

    var body: some View {
        ZStack {
            base
            Circle()
                .fill(accent.opacity(scheme == .dark ? 0.22 : 0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 120, y: -220)
            Circle()
                .fill(accent.opacity(scheme == .dark ? 0.12 : 0.07))
                .frame(width: 240, height: 240)
                .blur(radius: 80)
                .offset(x: -130, y: 260)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var base: Color {
        Color(uiColor: scheme == .dark ? .black : .systemBackground)
    }
}

/// Card surface used by roster rows and grouped content.
struct NativeCard: ViewModifier {
    var corner: CGFloat = NativeTheme.cardCorner

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    func nativeCard(corner: CGFloat = NativeTheme.cardCorner) -> some View {
        modifier(NativeCard(corner: corner))
    }

    /// Hide the platform scroll background so `NativeCanvas` shows through.
    @ViewBuilder func compatHiddenScrollBackground() -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self.onAppear { UITableView.appearance().backgroundColor = .clear }
        }
    }
}
#endif
