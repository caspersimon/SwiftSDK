import Foundation

/// Separates UI-affine reads from metadata preparation while retaining a single payload contract.
///
/// Injectable internally so tests exercise SignalManager's real queue transition without UI changes.
struct SignalMetadata: Sendable {
    let uiParameters: @MainActor @Sendable () -> [String: String]
    let backgroundParameters: @Sendable () -> [String: String]

    static let live = SignalMetadata(
        uiParameters: { DefaultSignalPayload.uiParameters },
        backgroundParameters: { DefaultSignalPayload.backgroundParameters }
    )
}
