import FlutterMacOS
import AppKit

public class LiquidGlassContainerFactory: NSObject, FlutterPlatformViewFactory {
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
      return LiquidGlassContainerNSView(frame: .zero, viewId: viewId, args: args, messenger: messenger).view()
    } else {
      return FallbackLiquidGlassContainerNSView(frame: .zero, viewId: viewId, args: args, messenger: messenger).view()
    }
  }
}

