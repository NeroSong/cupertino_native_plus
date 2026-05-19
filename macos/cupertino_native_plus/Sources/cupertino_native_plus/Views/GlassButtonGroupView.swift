import AppKit
import FlutterMacOS
import SwiftUI

// MARK: - ViewModel

@available(macOS 26.0, *)
class GlassButtonGroupViewModel: ObservableObject {
  @Published var buttons: [GlassButtonData] = []
  @Published var axis: Axis = .horizontal
  @Published var spacing: CGFloat = 8.0
  @Published var spacingForGlass: CGFloat = 40.0
}

// MARK: - SwiftUI View

@available(macOS 26.0, *)
struct GlassButtonGroupSwiftUI: View {
  @ObservedObject var viewModel: GlassButtonGroupViewModel
  @Namespace private var namespace

  var body: some View {
    GlassEffectContainer(spacing: viewModel.spacingForGlass) {
      if viewModel.axis == .horizontal {
        HStack(alignment: .center, spacing: viewModel.spacing) { buttonViews }
          .frame(
            minWidth: 0, maxWidth: .infinity,
            minHeight: 0, maxHeight: .infinity,
            alignment: .center
          )
      } else {
        VStack(alignment: .center, spacing: viewModel.spacing) { buttonViews }
          .frame(
            minWidth: 0, maxWidth: .infinity,
            minHeight: 0, maxHeight: .infinity,
            alignment: .center
          )
      }
    }
    .frame(
      minWidth: 0, maxWidth: .infinity,
      minHeight: 0, maxHeight: .infinity,
      alignment: .center
    )
  }

  @ViewBuilder
  private var buttonViews: some View {
    ForEach(viewModel.buttons) { button in
      GlassButtonSwiftUI(
        title: button.title,
        iconConfig: button.iconConfig,
        theme: button.theme,
        style: button.style,
        isEnabled: button.isEnabled,
        onPressed: button.onPressed,
        glassEffectUnionId: button.glassEffectUnionId,
        glassEffectId: button.glassEffectId,
        glassEffectInteractive: button.glassEffectInteractive,
        namespace: namespace,
        config: button.config,
        imagePlacement: button.imagePlacement,
        contentAlignment: button.contentAlignment
      )
    }
  }
}

// MARK: - Data Model

@available(macOS 26.0, *)
struct GlassButtonData: Identifiable {
  let id = UUID()
  let title: String?
  let iconConfig: IconConfig?
  let theme: CNButtonTheme
  let style: String
  let isEnabled: Bool
  let onPressed: () -> Void
  let glassEffectUnionId: String?
  let glassEffectId: String?
  let glassEffectInteractive: Bool
  let config: GlassButtonConfig
  let imagePlacement: String
  let contentAlignment: String
}

// MARK: - Platform View (macOS 26+)

@available(macOS 26.0, *)
class GlassButtonGroupPlatformView: NSObject {
  private let container: NSView
  private let hostingController: NSHostingController<GlassButtonGroupSwiftUI>
  private let viewModel: GlassButtonGroupViewModel
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.container = NSView(frame: frame)
    self.container.wantsLayer = true
    self.container.layer?.backgroundColor = NSColor.clear.cgColor

    let channel = FlutterMethodChannel(
      name: "\(ChannelConstants.viewIdCupertinoNativeGlassButtonGroup)_\(viewId)",
      binaryMessenger: messenger
    )
    self.channel = channel

    let viewModel = GlassButtonGroupViewModel()
    self.viewModel = viewModel

    var isDark = false

    if let dict = args as? [String: Any] {
      isDark = dict["isDark"] as? Bool ?? false

      if let buttonsData = dict["buttons"] as? [[String: Any]] {
        viewModel.buttons = buttonsData.enumerated().map { index, d in
          Self.parseButtonData(from: d, index: index, channel: channel)
        }
      }
      if let axisStr = dict["axis"] as? String {
        viewModel.axis = axisStr == "horizontal" ? .horizontal : .vertical
      }
      if let v = dict["spacing"] as? NSNumber {
        viewModel.spacing = CGFloat(truncating: v)
      }
      if let v = dict["spacingForGlass"] as? NSNumber {
        viewModel.spacingForGlass = CGFloat(truncating: v)
      }
    }

    let swiftUIView = GlassButtonGroupSwiftUI(viewModel: viewModel)
    self.hostingController = NSHostingController(rootView: swiftUIView)
    self.hostingController.view.wantsLayer = true
    self.hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
    self.hostingController.view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    super.init()

    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(hostingController.view)
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    setupMethodChannel()
  }

  func view() -> NSView { container }

  // MARK: - Method Channel

  private func setupMethodChannel() {
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterMethodNotImplemented); return }

      switch call.method {
      case "updateButton":
        guard let args = call.arguments as? [String: Any],
              let index = args["index"] as? Int,
              let dict = args["button"] as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "Missing index or button", details: nil))
          return
        }
        guard index >= 0, index < self.viewModel.buttons.count else {
          result(FlutterError(code: "bad_index", message: "Index out of range", details: nil))
          return
        }
        self.viewModel.buttons[index] = Self.parseButtonData(
          from: dict, index: index, channel: self.channel
        )
        result(nil)

      case "updateButtons":
        guard let args = call.arguments as? [String: Any],
              let buttonsData = args["buttons"] as? [[String: Any]] else {
          result(FlutterError(code: "bad_args", message: "Missing buttons", details: nil))
          return
        }
        self.viewModel.buttons = buttonsData.enumerated().map { index, d in
          Self.parseButtonData(from: d, index: index, channel: self.channel)
        }
        result(nil)

      case ChannelConstants.methodSetBrightness:
        guard let args = call.arguments as? [String: Any],
              let isDark = (args["isDark"] as? NSNumber)?.boolValue else {
          result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
          return
        }
        self.hostingController.view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Parsing helpers

  /// Pre-converts any `FlutterStandardTypedData` values to `Data` so
  /// `IconConfig.from(dict:)` and `CNIcon.from(dict:)` can read them.
  private static func preprocessDict(_ dict: [String: Any]) -> [String: Any] {
    var out = dict
    for (key, value) in dict {
      if let typedData = value as? FlutterStandardTypedData {
        out[key] = typedData.data
      }
    }
    return out
  }

  /// Parses a button dictionary into a `GlassButtonData`.
  private static func parseButtonData(
    from dict: [String: Any],
    index: Int,
    channel: FlutterMethodChannel
  ) -> GlassButtonData {
    let processed = preprocessDict(dict)

    let title = processed["label"] as? String
    let isEnabled = (processed["enabled"] as? NSNumber)?.boolValue ?? true
    let style = processed["style"] as? String ?? "glass"
    let glassEffectUnionId = processed["glassEffectUnionId"] as? String
    let glassEffectId = processed["glassEffectId"] as? String
    let glassEffectInteractive = (processed["glassEffectInteractive"] as? NSNumber)?.boolValue ?? false

    let iconConfig = IconConfig.from(dict: processed)
    let theme = CNButtonTheme.from(dict: processed)

    let config = GlassButtonConfig(
      borderRadius: (processed["borderRadius"] as? NSNumber).map { CGFloat(truncating: $0) },
      top: (processed["paddingTop"] as? NSNumber).map { CGFloat(truncating: $0) },
      bottom: (processed["paddingBottom"] as? NSNumber).map { CGFloat(truncating: $0) },
      left: (processed["paddingLeft"] as? NSNumber).map { CGFloat(truncating: $0) },
      right: (processed["paddingRight"] as? NSNumber).map { CGFloat(truncating: $0) },
      horizontal: (processed["paddingHorizontal"] as? NSNumber).map { CGFloat(truncating: $0) },
      vertical: (processed["paddingVertical"] as? NSNumber).map { CGFloat(truncating: $0) },
      minHeight: (processed["minHeight"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 44.0,
      spacing: (processed["imagePadding"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 8.0,
      contentAlignment: processed["contentAlignment"] as? String ?? "center"
    )

    let imagePlacement = processed["imagePlacement"] as? String ?? "leading"
    let contentAlignment = processed["contentAlignment"] as? String ?? "center"

    let callback: () -> Void = {
      CNGlassHaptics.impact()
      channel.invokeMethod("buttonPressed", arguments: ["index": index], result: nil as FlutterResult?)
    }

    return GlassButtonData(
      title: title,
      iconConfig: iconConfig.hasIcon ? iconConfig : nil,
      theme: theme,
      style: style,
      isEnabled: isEnabled,
      onPressed: callback,
      glassEffectUnionId: glassEffectUnionId,
      glassEffectId: glassEffectId,
      glassEffectInteractive: glassEffectInteractive,
      config: config,
      imagePlacement: imagePlacement,
      contentAlignment: contentAlignment
    )
  }
}
