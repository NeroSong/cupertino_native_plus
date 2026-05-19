import FlutterMacOS
import AppKit

public class CupertinoSearchBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  public init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  public func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  public func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    return CupertinoSearchBarNSView(
      frame: .zero,
      viewId: viewId,
      args: args,
      messenger: messenger
    ).view()
  }
}
