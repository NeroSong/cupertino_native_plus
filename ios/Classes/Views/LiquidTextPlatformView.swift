import Flutter
import UIKit
import SwiftUI

// MARK: - Config

@available(iOS 26.0, *)
struct LiquidTextConfig {
  let text: String
  let fontSize: CGFloat
  let fontWeight: Font.Weight
  let textColor: Color?
  let shape: String          // "capsule" | "rect" | "circle"
  let cornerRadius: CGFloat?
  let tint: Color?
  let interactive: Bool
  let padding: EdgeInsets
  let isDark: Bool

  static func parse(from args: Any?) -> LiquidTextConfig {
    guard let dict = args as? [String: Any] else { return .default }

    let text = dict["text"] as? String ?? ""
    let fontSize = (dict["fontSize"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 16.0
    let fontWeight = parseFontWeight(dict["fontWeight"] as? String)

    let textColorARGB = (dict["textColor"] as? NSNumber)?.intValue
    let textColor = textColorARGB.map { Color(uiColor: ImageUtils.colorFromARGB($0)) }

    let shape = dict["shape"] as? String ?? "capsule"
    let cornerRadius = (dict["cornerRadius"] as? NSNumber).map { CGFloat(truncating: $0) }

    let tintARGB = (dict["tint"] as? NSNumber)?.intValue
    let tint = tintARGB.map { Color(uiColor: ImageUtils.colorFromARGB($0)) }

    let interactive = (dict["interactive"] as? NSNumber)?.boolValue ?? false
    let isDark = dict["isDark"] as? Bool ?? false

    let all: CGFloat? = (dict["padding"] as? NSNumber).map { CGFloat(truncating: $0) }
    let padding = EdgeInsets(
      top:      (dict["paddingTop"]    as? NSNumber).map { CGFloat(truncating: $0) } ?? all ?? 8.0,
      leading:  (dict["paddingLeft"]   as? NSNumber).map { CGFloat(truncating: $0) } ?? all ?? 12.0,
      bottom:   (dict["paddingBottom"] as? NSNumber).map { CGFloat(truncating: $0) } ?? all ?? 8.0,
      trailing: (dict["paddingRight"]  as? NSNumber).map { CGFloat(truncating: $0) } ?? all ?? 12.0
    )

    return LiquidTextConfig(
      text: text, fontSize: fontSize, fontWeight: fontWeight, textColor: textColor,
      shape: shape, cornerRadius: cornerRadius, tint: tint, interactive: interactive,
      padding: padding, isDark: isDark
    )
  }

  static var `default`: LiquidTextConfig {
    LiquidTextConfig(
      text: "", fontSize: 16, fontWeight: .regular, textColor: nil,
      shape: "capsule", cornerRadius: nil, tint: nil, interactive: false,
      padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12), isDark: false
    )
  }

  private static func parseFontWeight(_ str: String?) -> Font.Weight {
    switch str {
    case "bold":       return .bold
    case "semibold":   return .semibold
    case "medium":     return .medium
    case "light":      return .light
    case "thin":       return .thin
    case "ultraLight": return .ultraLight
    case "heavy":      return .heavy
    case "black":      return .black
    default:           return .regular
    }
  }
}

// MARK: - ViewModel

@available(iOS 26.0, *)
final class LiquidTextViewModel: ObservableObject {
  @Published var text: String
  @Published var fontSize: CGFloat
  @Published var fontWeight: Font.Weight
  @Published var textColor: Color?
  @Published var shape: String
  @Published var cornerRadius: CGFloat?
  @Published var tint: Color?
  @Published var interactive: Bool
  @Published var padding: EdgeInsets

  init(config: LiquidTextConfig) {
    self.text = config.text
    self.fontSize = config.fontSize
    self.fontWeight = config.fontWeight
    self.textColor = config.textColor
    self.shape = config.shape
    self.cornerRadius = config.cornerRadius
    self.tint = config.tint
    self.interactive = config.interactive
    self.padding = config.padding
  }

  func apply(_ config: LiquidTextConfig) {
    text = config.text
    fontSize = config.fontSize
    fontWeight = config.fontWeight
    textColor = config.textColor
    shape = config.shape
    cornerRadius = config.cornerRadius
    tint = config.tint
    interactive = config.interactive
    padding = config.padding
  }
}

// MARK: - SwiftUI View

@available(iOS 26.0, *)
struct LiquidTextSwiftUI: View {
  @ObservedObject var viewModel: LiquidTextViewModel

  var body: some View {
    let s = glassShape
    // Only override foreground when a color is explicitly set.
    // Without this, the glass effect applies natural vibrant text treatment.
    styledText
      .padding(viewModel.padding)
      .glassEffect(glassEffect, in: s)
      .animation(.easeInOut(duration: 0.25), value: animState)
  }

  @ViewBuilder
  private var styledText: some View {
    if let color = viewModel.textColor {
      Text(viewModel.text)
        .font(.system(size: viewModel.fontSize, weight: viewModel.fontWeight))
        .foregroundStyle(color)
    } else {
      Text(viewModel.text)
        .font(.system(size: viewModel.fontSize, weight: viewModel.fontWeight))
    }
  }

  private var glassEffect: Glass {
    var glass = Glass.regular
    if let tint = viewModel.tint { glass = glass.tint(tint) }
    if viewModel.interactive { glass = glass.interactive() }
    return glass
  }

  private var glassShape: AnyShape {
    switch viewModel.shape {
    case "rect":   return AnyShape(RoundedRectangle(cornerRadius: viewModel.cornerRadius ?? 0))
    case "circle": return AnyShape(Circle())
    default:       return AnyShape(Capsule())
    }
  }

  // MARK: - Animation state

  private struct AnimState: Equatable {
    let text: String
    let fontSize: CGFloat
    let textColor: Color?
    let tint: Color?
    let interactive: Bool
    let shape: String
    let cornerRadius: CGFloat?
  }

  private var animState: AnimState {
    AnimState(
      text: viewModel.text,
      fontSize: viewModel.fontSize,
      textColor: viewModel.textColor,
      tint: viewModel.tint,
      interactive: viewModel.interactive,
      shape: viewModel.shape,
      cornerRadius: viewModel.cornerRadius
    )
  }
}

// MARK: - Platform View (iOS 26+)

@available(iOS 26.0, *)
class LiquidTextPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let hostingController: UIHostingController<LiquidTextSwiftUI>
  private let channel: FlutterMethodChannel
  private let viewModel: LiquidTextViewModel

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "\(ChannelConstants.viewIdCNLiquidText)_\(viewId)",
      binaryMessenger: messenger
    )
    self.container = UIView(frame: frame)
    self.container.backgroundColor = .clear
    self.container.clipsToBounds = false

    let config = LiquidTextConfig.parse(from: args)
    let viewModel = LiquidTextViewModel(config: config)
    self.viewModel = viewModel

    self.hostingController = UIHostingController(rootView: LiquidTextSwiftUI(viewModel: viewModel))
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

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case ChannelConstants.methodUpdateConfig:
        let cfg = LiquidTextConfig.parse(from: call.arguments)
        self.viewModel.apply(cfg)
        self.hostingController.overrideUserInterfaceStyle = cfg.isDark ? .dark : .light
        result(nil)
      case ChannelConstants.methodSetBrightness:
        if let dict = call.arguments as? [String: Any],
           let isDark = (dict["isDark"] as? NSNumber)?.boolValue {
          self.hostingController.overrideUserInterfaceStyle = isDark ? .dark : .light
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView { container }
}

// MARK: - Fallback (iOS < 26)

class FallbackLiquidTextView: NSObject, FlutterPlatformView {
  private let container: UIView

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.container = UIView(frame: frame)
    self.container.backgroundColor = .clear
    super.init()
  }

  func view() -> UIView { container }
}
