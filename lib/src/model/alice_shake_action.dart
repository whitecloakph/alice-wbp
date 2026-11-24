/// What a device shake does (only on a physical Android or iOS device with an
/// accelerometer; see [AliceConfiguration.showInspectorOnShake]).
enum AliceShakeAction {
  /// Opens the inspector. Upstream Alice behaviour and the default.
  openInspector,

  /// Shows the floating overlay bubble if it is hidden, hides it otherwise.
  /// A bubble hidden this way stays hidden when new calls arrive.
  toggleOverlayBubble,
}
