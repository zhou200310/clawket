//
//  Compat.swift
//  ClawketUI
//
//  Backwards-compatible shims so ClawketUI (and the iOS host) can build with an
//  iOS 15.4 deployment target while still using the iOS 16+ APIs when they exist.
//
//  Every shim prefers the native API on iOS 16 / macOS 13 and falls back to a
//  conservative SwiftUI 1/2/3 equivalent otherwise.
//

import SwiftUI

// MARK: - NavigationStack

/// `NavigationStack` on iOS 16+, `NavigationView` (stack style) before that.
@MainActor
public struct CompatNavigationStack<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationStack { content }
        } else {
            #if os(iOS)
            NavigationView { content }
                .navigationViewStyle(.stack)
            #else
            NavigationView { content }
            #endif
        }
    }
}

/// `NavigationLink(value:)` on iOS 16+, destination-based link before that.
///
/// Value-based links only work together with `navigationDestination(for:)`,
/// which does not exist before iOS 16, so the fallback needs a real destination.
@MainActor
public struct CompatNavigationLink<Value: Hashable, Label: View, Destination: View>: View {
    private let value: Value
    private let label: Label
    private let destination: Destination

    public init(value: Value,
                @ViewBuilder label: () -> Label,
                @ViewBuilder destination: () -> Destination) {
        self.value = value
        self.label = label()
        self.destination = destination()
    }

    public var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationLink(value: value) { label }
        } else {
            NavigationLink(destination: destination) { label }
        }
    }
}

// MARK: - LabeledContent

/// `LabeledContent` on iOS 16+, an `HStack` with a secondary value before that.
@MainActor
public struct CompatLabeledContent<Label: View, Content: View>: View {
    private let label: Label
    private let content: Content

    public init(@ViewBuilder content: () -> Content,
                @ViewBuilder label: () -> Label) {
        self.content = content()
        self.label = label()
    }

    public init(_ titleKey: LocalizedStringKey,
                @ViewBuilder content: () -> Content) where Label == Text {
        self.init(content: content) { Text(titleKey) }
    }

    public init<S: StringProtocol>(_ title: S,
                                   @ViewBuilder content: () -> Content) where Label == Text {
        self.init(content: content) { Text(String(title)) }
    }

    public init(_ titleKey: LocalizedStringKey, value: String) where Label == Text, Content == Text {
        self.init(content: { Text(value) }) { Text(titleKey) }
    }

    public init<S: StringProtocol>(_ title: S, value: String) where Label == Text, Content == Text {
        self.init(content: { Text(value) }) { Text(String(title)) }
    }

    public var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            LabeledContent { content } label: { label }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                label
                Spacer(minLength: 8)
                content.foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Toolbar

/// Disambiguates `toolbar(content:)` (View vs ToolbarContent overloads) on iOS 15.
extension View {
    @MainActor @ViewBuilder
    public func compatToolbar<C: ToolbarContent>(@ToolbarContentBuilder _ content: () -> C) -> some View {
        self.toolbar(content)
    }
}

// MARK: - ViewThatFits

/// `ViewThatFits` on iOS 16+, the primary variant before that.
@MainActor
public struct CompatViewThatFits<Primary: View, Fallback: View>: View {
    private let axes: Axis.Set
    private let primary: Primary
    private let fallback: Fallback

    public init(in axes: Axis.Set = .horizontal,
                @ViewBuilder primary: () -> Primary,
                @ViewBuilder fallback: () -> Fallback) {
        self.axes = axes
        self.primary = primary()
        self.fallback = fallback()
    }

    public var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            ViewThatFits(in: axes) {
                primary
                fallback
            }
        } else {
            primary
        }
    }
}

// MARK: - Presentation detents

/// Availability-safe stand-in for `PresentationDetent`.
public enum CompatPresentationDetent: Hashable {
    case medium
    case large
    case fraction(CGFloat)
    case height(CGFloat)

    @available(iOS 16.0, macOS 13.0, *)
    fileprivate var native: PresentationDetent {
        switch self {
        case .medium: return .medium
        case .large: return .large
        case let .fraction(value): return .fraction(value)
        case let .height(value): return .height(value)
        }
    }
}

public extension View {
    /// Applies `presentationDetents` on iOS 16+, no-op before that.
    @ViewBuilder
    func compatPresentationDetents(_ detents: Set<CompatPresentationDetent>) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.presentationDetents(Set(detents.map(\.native)))
        } else {
            self
        }
    }

    /// Applies `presentationDragIndicator` on iOS 16+, no-op before that.
    @ViewBuilder
    func compatPresentationDragIndicator(_ visibility: Visibility) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.presentationDragIndicator(visibility)
        } else {
            self
        }
    }
}

// MARK: - Scroll view modifiers

public extension View {
    /// Applies `scrollContentBackground` on iOS 16+, no-op before that.
    @ViewBuilder
    func compatScrollContentBackground(_ visibility: Visibility) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.scrollContentBackground(visibility)
        } else {
            self
        }
    }
}

/// Availability-safe stand-in for `ScrollDismissesKeyboardMode`.
public enum CompatScrollDismissesKeyboardMode {
    case automatic
    case immediately
    case interactively
    case never

    @available(iOS 16.0, macOS 13.0, *)
    fileprivate var native: ScrollDismissesKeyboardMode {
        switch self {
        case .automatic: return .automatic
        case .immediately: return .immediately
        case .interactively: return .interactively
        case .never: return .never
        }
    }
}

/// Availability-safe stand-in for `ScrollBounceBehavior`.
public enum CompatScrollBounceBehavior {
    case automatic
    case always
    case basedOnSize

    @available(iOS 16.4, macOS 13.3, *)
    fileprivate var native: ScrollBounceBehavior {
        switch self {
        case .automatic: return .automatic
        case .always: return .always
        case .basedOnSize: return .basedOnSize
        }
    }
}

public extension View {
    /// Applies `scrollDismissesKeyboard` on iOS 16+, no-op before that.
    @ViewBuilder
    func compatScrollDismissesKeyboard(_ mode: CompatScrollDismissesKeyboardMode) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.scrollDismissesKeyboard(mode.native)
        } else {
            self
        }
    }

    /// Applies `scrollBounceBehavior` on iOS 16.4+, no-op before that.
    @ViewBuilder
    func compatScrollBounceBehavior(_ behavior: CompatScrollBounceBehavior) -> some View {
        if #available(iOS 16.4, macOS 13.3, *) {
            self.scrollBounceBehavior(behavior.native)
        } else {
            self
        }
    }

    /// Applies `navigationDestination(for:)` on iOS 16+, no-op before that.
    /// Pair it with `CompatNavigationLink`, whose fallback carries a real destination.
    @ViewBuilder
    func compatNavigationDestination<D: Hashable, C: View>(
        for data: D.Type,
        @ViewBuilder destination: @escaping (D) -> C
    ) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.navigationDestination(for: data, destination: destination)
        } else {
            self
        }
    }
}
