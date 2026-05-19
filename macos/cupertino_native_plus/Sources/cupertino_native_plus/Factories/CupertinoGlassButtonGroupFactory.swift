import FlutterMacOS
import AppKit

public class CupertinoGlassButtonGroupFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  public init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  public func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  public func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    if #available(macOS 26.0, *) {
      return GlassButtonGroupPlatformView(
        frame: .zero, viewId: viewId, args: args, messenger: messenger
      ).view()
    }
    return FallbackGlassButtonGroupView(frame: .zero).view()
  }
}

// MARK: - Fallback (macOS < 26)

class FallbackGlassButtonGroupView: NSObject {
  private let container: NSView

  init(frame: CGRect) {
    self.container = NSView(frame: frame)
    self.container.wantsLayer = true
    self.container.layer?.backgroundColor = NSColor.clear.cgColor
    super.init()
  }

  func view() -> NSView { container }
}
