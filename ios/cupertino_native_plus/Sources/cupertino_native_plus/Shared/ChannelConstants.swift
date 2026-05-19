import Foundation

/// Centralized channel names and view-type IDs. Keep in sync with Dart [ViewTypes].
public enum ChannelConstants {
  /// Method channel name for the plugin.
  public static let methodChannelName = "cupertino_native"

  /// Native tab bar method channel (single channel, not per-view).
  public static let cnNativeTabBarChannel = "cn_native_tab_bar"

  // MARK: - View type IDs (must match lib/channel/view_types.dart)

  public static let viewIdCupertinoNativeButton = "CupertinoNativeButton"
  public static let viewIdCupertinoNativeGlassButtonGroup = "CupertinoNativeGlassButtonGroup"
  public static let viewIdCupertinoNativeIcon = "CupertinoNativeIcon"
  public static let viewIdCupertinoNativeLiquidGlassContainer = "CupertinoNativeLiquidGlassContainer"
  public static let viewIdCupertinoNativePopupMenuButton = "CupertinoNativePopupMenuButton"
  public static let viewIdCupertinoNativeSegmentedControl = "CupertinoNativeSegmentedControl"
  public static let viewIdCupertinoNativeSlider = "CupertinoNativeSlider"
  public static let viewIdCupertinoNativeSwitch = "CupertinoNativeSwitch"
  public static let viewIdCupertinoNativeTabBar = "CupertinoNativeTabBar"
  public static let viewIdCNFloatingIsland = "CNFloatingIsland"
  public static let viewIdCNGlassCardWithSpotlight = "CNGlassCardWithSpotlight"
  public static let viewIdCNGlassCard = "CNGlassCard"
  public static let viewIdCNSearchBar = "CNSearchBar"
  public static let viewIdCNSearchScaffold = "CNSearchScaffold"
  public static let viewIdCNLiquidText = "CNLiquidText"

  // MARK: - Method names

  public static let methodGetPlatformVersion = "getPlatformVersion"
  public static let methodGetMajorOSVersion = "getMajorOSVersion"
  public static let methodUpdateConfig = "updateConfig"
  public static let methodSetBrightness = "setBrightness"
  public static let methodPressed = "pressed"
  public static let methodValueChanged = "valueChanged"
  public static let methodItemSelected = "itemSelected"
  public static let methodExpanded = "expanded"
  public static let methodCollapsed = "collapsed"
  public static let methodTapped = "tapped"
}
