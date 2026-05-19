import AppKit
import SwiftUI

// MARK: - NoHighlightButtonStyle (macOS)

/// Removes all default button press highlights so the glass effect handles visual feedback.
///
/// macOS counterpart to the iOS `NoHighlightButtonStyle`. Used by the glass-button
/// group so the SwiftUI `Button` does not paint AppKit's bezeled chrome over the
/// glass effect.
@available(macOS 26.0, *)
struct NoHighlightButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.85 : 1.0)
      .contentShape(Rectangle())
  }
}

// MARK: - Haptics shim (macOS)

/// Lightweight haptic feedback helper. iOS uses `UIImpactFeedbackGenerator`;
/// macOS does not have a direct equivalent for the SwiftUI button press path,
/// so we forward to `NSHapticFeedbackManager` which is the closest analog.
@available(macOS 26.0, *)
enum CNGlassHaptics {
  static func impact() {
    NSHapticFeedbackManager.defaultPerformer.perform(
      .alignment,
      performanceTime: .now
    )
  }
}
