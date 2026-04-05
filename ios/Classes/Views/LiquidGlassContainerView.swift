import Flutter
import UIKit
import SwiftUI

// MARK: - ViewModel

@available(iOS 26.0, *)
final class LiquidGlassContainerViewModel: ObservableObject {
  @Published var effect: String
  @Published var shape: String
  @Published var cornerRadius: CGFloat?
  @Published var tint: UIColor?
  @Published var interactive: Bool

  init(effect: String, shape: String, cornerRadius: CGFloat?, tint: UIColor?, interactive: Bool) {
    self.effect = effect
    self.shape = shape
    self.cornerRadius = cornerRadius
    self.tint = tint
    self.interactive = interactive
  }

  func apply(effect: String, shape: String, cornerRadius: CGFloat?, tint: UIColor?, interactive: Bool) {
    self.effect = effect
    self.shape = shape
    self.cornerRadius = cornerRadius
    self.tint = tint
    self.interactive = interactive
  }
}

// MARK: - Platform View (iOS 26+)

@available(iOS 26.0, *)
class LiquidGlassContainerPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let hostingController: UIHostingController<LiquidGlassContainerSwiftUI>
  private let channel: FlutterMethodChannel
  private let viewModel: LiquidGlassContainerViewModel

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "\(ChannelConstants.viewIdCupertinoNativeLiquidGlassContainer)_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    self.container.backgroundColor = .clear
    self.container.clipsToBounds = false

    let config = LiquidGlassContainerConfig.parse(from: args)
    let tint = config.tintARGB.map { ImageUtils.colorFromARGB($0) }

    let viewModel = LiquidGlassContainerViewModel(
      effect: config.effect,
      shape: config.shape,
      cornerRadius: config.cornerRadius,
      tint: tint,
      interactive: config.interactive
    )
    self.viewModel = viewModel

    let glassView = LiquidGlassContainerSwiftUI(viewModel: viewModel)
    self.hostingController = UIHostingController(rootView: glassView)
    self.hostingController.view.backgroundColor = .clear
    self.hostingController.overrideUserInterfaceStyle = config.isDark ? .dark : .light

    super.init()

    container.addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    channel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == ChannelConstants.methodUpdateConfig {
        self?.updateConfig(args: call.arguments)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func updateConfig(args: Any?) {
    let config = LiquidGlassContainerConfig.parse(from: args)
    let tint = config.tintARGB.map { ImageUtils.colorFromARGB($0) }
    viewModel.apply(effect: config.effect, shape: config.shape, cornerRadius: config.cornerRadius, tint: tint, interactive: config.interactive)
    hostingController.overrideUserInterfaceStyle = config.isDark ? .dark : .light
  }

  func view() -> UIView {
    return container
  }
}

// MARK: - SwiftUI View

@available(iOS 26.0, *)
struct LiquidGlassContainerSwiftUI: View {
  @ObservedObject var viewModel: LiquidGlassContainerViewModel

  var body: some View {
    GeometryReader { geometry in
      shapeForConfig()
        .fill(Color.clear)
        .contentShape(shapeForConfig())
        .allowsHitTesting(viewModel.interactive)  // Only intercept touches when interactive glass is enabled
        .glassEffect(glassEffectForConfig(), in: shapeForConfig())
        .frame(width: geometry.size.width, height: geometry.size.height)
        .animation(.easeInOut(duration: 0.25), value: configIdentity)
    }
  }

  /// Single Equatable value for animation to avoid multiple animation pipelines (reduces jank).
  private var configIdentity: String {
    "\(viewModel.effect)|\(viewModel.shape)|\(viewModel.cornerRadius ?? -1)|\(viewModel.interactive)"
  }

  private func glassEffectForConfig() -> Glass {
    // Always use .regular for now - prominent glass API may be available in future
    var glass = Glass.regular

    if let tintColor = viewModel.tint {
      glass = glass.tint(Color(tintColor))
    }

    if viewModel.interactive {
      glass = glass.interactive()
    }

    return glass
  }

  private func shapeForConfig() -> some Shape {
    switch viewModel.shape {
    case "rect":
      if let radius = viewModel.cornerRadius {
        return AnyShape(RoundedRectangle(cornerRadius: radius))
      }
      return AnyShape(RoundedRectangle(cornerRadius: 0))
    case "circle":
      return AnyShape(Circle())
    default: // capsule
      return AnyShape(Capsule())
    }
  }
}

// MARK: - Fallback (iOS < 26)

class FallbackLiquidGlassContainerView: NSObject, FlutterPlatformView {
  private let container: UIView

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.container = UIView(frame: frame)
    self.container.backgroundColor = .clear
    super.init()
  }

  func view() -> UIView {
    return container
  }
}
