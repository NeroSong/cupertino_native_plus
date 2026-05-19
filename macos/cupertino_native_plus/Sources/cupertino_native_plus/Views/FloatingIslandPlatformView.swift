import FlutterMacOS
import AppKit
import SwiftUI

class FloatingIslandPlatformView: NSObject {
  private let channel: FlutterMethodChannel
  private let container: NSView
  private let hostingController: NSHostingController<FloatingIslandSwiftUI>
  private var viewModel: FloatingIslandViewModel

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "\(ChannelConstants.viewIdCNFloatingIsland)_\(viewId)",
      binaryMessenger: messenger
    )
    self.container = NSView(frame: frame)
    self.viewModel = FloatingIslandViewModel()

    // Parse arguments
    var isExpanded = false
    var position = "top"
    var collapsedHeight: CGFloat = 44
    var collapsedWidth: CGFloat? = nil
    var expandedHeight: CGFloat? = nil
    var expandedWidth: CGFloat? = nil
    var cornerRadius: CGFloat = 22
    var tintNSColor: NSColor? = nil
    var springDamping: CGFloat = 0.8
    var springResponse: CGFloat = 0.4
    var isDark = false

    if let dict = args as? [String: Any] {
      if let v = dict["isExpanded"] as? Bool { isExpanded = v }
      if let v = dict["position"] as? String { position = v }
      if let v = dict["collapsedHeight"] as? NSNumber { collapsedHeight = CGFloat(truncating: v) }
      if let v = dict["collapsedWidth"] as? NSNumber { collapsedWidth = CGFloat(truncating: v) }
      if let v = dict["expandedHeight"] as? NSNumber { expandedHeight = CGFloat(truncating: v) }
      if let v = dict["expandedWidth"] as? NSNumber { expandedWidth = CGFloat(truncating: v) }
      if let v = dict["cornerRadius"] as? NSNumber { cornerRadius = CGFloat(truncating: v) }
      if let v = dict["tint"] as? NSNumber { tintNSColor = ImageUtils.colorFromARGB(v.intValue) }
      if let v = dict["springDamping"] as? NSNumber { springDamping = CGFloat(truncating: v) }
      if let v = dict["springResponse"] as? NSNumber { springResponse = CGFloat(truncating: v) }
      if let v = dict["isDark"] as? Bool { isDark = v }
    }

    viewModel.isExpanded = isExpanded
    viewModel.collapsedHeight = collapsedHeight
    viewModel.collapsedWidth = collapsedWidth ?? 160
    viewModel.expandedHeight = expandedHeight ?? 200
    viewModel.expandedWidth = expandedWidth
    viewModel.cornerRadius = cornerRadius
    viewModel.tint = tintNSColor.map { nsColor -> Color in
      let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
      var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
      converted.getRed(&r, green: &g, blue: &b, alpha: &a)
      return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
    viewModel.springDamping = springDamping
    viewModel.springResponse = springResponse
    viewModel.isTop = position == "top"

    // Create SwiftUI view
    let floatingIslandView = FloatingIslandSwiftUI(viewModel: viewModel)
    self.hostingController = NSHostingController(rootView: floatingIslandView)

    super.init()

    container.wantsLayer = true
    container.layer?.backgroundColor = NSColor.clear.cgColor

    hostingController.view.wantsLayer = true
    hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
    hostingController.view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(hostingController.view)

    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    setupMethodChannel()
    setupCallbacks()
  }

  private func setupMethodChannel() {
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }

      switch call.method {
      case "expand":
        let animated = (call.arguments as? [String: Any])?["animated"] as? Bool ?? true
        self.applyExpanded(true, animated: animated)
        result(nil)

      case "collapse":
        let animated = (call.arguments as? [String: Any])?["animated"] as? Bool ?? true
        self.applyExpanded(false, animated: animated)
        result(nil)

      case ChannelConstants.methodSetBrightness:
        if let args = call.arguments as? [String: Any],
           let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          self.hostingController.view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
        }

      case ChannelConstants.methodUpdateConfig:
        self.updateConfig(args: call.arguments)
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func applyExpanded(_ expanded: Bool, animated: Bool) {
    if animated {
      if #available(macOS 14.0, *) {
        withAnimation(.spring(response: self.viewModel.springResponse, dampingFraction: self.viewModel.springDamping)) {
          self.viewModel.isExpanded = expanded
        }
      } else {
        withAnimation(.easeInOut(duration: 0.3)) {
          self.viewModel.isExpanded = expanded
        }
      }
    } else {
      self.viewModel.isExpanded = expanded
    }
  }

  private func updateConfig(args: Any?) {
    guard let dict = args as? [String: Any] else { return }
    if let v = dict["collapsedHeight"] as? NSNumber { viewModel.collapsedHeight = CGFloat(truncating: v) }
    if let v = dict["collapsedWidth"] as? NSNumber { viewModel.collapsedWidth = CGFloat(truncating: v) }
    if let v = dict["expandedHeight"] as? NSNumber { viewModel.expandedHeight = CGFloat(truncating: v) }
    if let v = dict["expandedWidth"] as? NSNumber { viewModel.expandedWidth = CGFloat(truncating: v) }
    if let v = dict["cornerRadius"] as? NSNumber { viewModel.cornerRadius = CGFloat(truncating: v) }
    if let v = dict["springDamping"] as? NSNumber { viewModel.springDamping = CGFloat(truncating: v) }
    if let v = dict["springResponse"] as? NSNumber { viewModel.springResponse = CGFloat(truncating: v) }
    if let v = dict["position"] as? String { viewModel.isTop = v == "top" }
    if let v = dict["tint"] as? NSNumber {
      let nsColor = ImageUtils.colorFromARGB(v.intValue)
      let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
      var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
      converted.getRed(&r, green: &g, blue: &b, alpha: &a)
      viewModel.tint = Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
    if let v = dict["isDark"] as? Bool {
      hostingController.view.appearance = NSAppearance(named: v ? .darkAqua : .aqua)
    }
  }

  private func setupCallbacks() {
    viewModel.onExpandedChanged = { [weak self] expanded in
      self?.channel.invokeMethod(expanded ? ChannelConstants.methodExpanded : ChannelConstants.methodCollapsed, arguments: nil)
    }
    viewModel.onTapped = { [weak self] in
      self?.channel.invokeMethod(ChannelConstants.methodTapped, arguments: nil)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> NSView {
    return container
  }
}

// MARK: - View Model

class FloatingIslandViewModel: ObservableObject {
  @Published var isExpanded: Bool = false {
    didSet {
      if oldValue != isExpanded {
        onExpandedChanged?(isExpanded)
      }
    }
  }
  @Published var collapsedHeight: CGFloat = 44
  @Published var collapsedWidth: CGFloat = 160
  @Published var expandedHeight: CGFloat = 200
  @Published var expandedWidth: CGFloat? = nil
  @Published var cornerRadius: CGFloat = 22
  @Published var tint: Color? = nil
  @Published var springDamping: CGFloat = 0.8
  @Published var springResponse: CGFloat = 0.4
  @Published var isTop: Bool = true

  var onExpandedChanged: ((Bool) -> Void)?
  var onTapped: (() -> Void)?
}

// MARK: - SwiftUI View

struct FloatingIslandSwiftUI: View {
  @ObservedObject var viewModel: FloatingIslandViewModel

  var body: some View {
    GeometryReader { geometry in
      let maxWidth = geometry.size.width
      let expandedWidth = viewModel.expandedWidth ?? (maxWidth - 32)
      let currentWidth = viewModel.isExpanded ? expandedWidth : viewModel.collapsedWidth
      let currentHeight = viewModel.isExpanded ? viewModel.expandedHeight : viewModel.collapsedHeight
      let currentRadius = viewModel.isExpanded ? 24 : viewModel.cornerRadius

      VStack {
        if !viewModel.isTop {
          Spacer()
        }

        islandContent(width: currentWidth, height: currentHeight, cornerRadius: currentRadius)
          .frame(width: currentWidth, height: currentHeight)

        if viewModel.isTop {
          Spacer()
        }
      }
      .frame(maxWidth: .infinity)
    }
  }

  @ViewBuilder
  private func islandContent(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
    if #available(macOS 26.0, *) {
      // Native glass effect on macOS 26+
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(.clear)
        .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onTapGesture {
          withAnimation(.spring(response: viewModel.springResponse, dampingFraction: viewModel.springDamping)) {
            viewModel.onTapped?()
          }
        }
    } else {
      // Fallback for older macOS
      fallbackIslandContent(cornerRadius: cornerRadius)
    }
  }

  @ViewBuilder
  private func fallbackIslandContent(cornerRadius: CGFloat) -> some View {
    let tintColor = viewModel.tint
    RoundedRectangle(cornerRadius: cornerRadius)
      .fill(tintColor != nil ? tintColor!.opacity(0.3) : Color(NSColor.windowBackgroundColor).opacity(0.9))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
      )
      .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
      .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
      .onTapGesture {
        if #available(macOS 14.0, *) {
          withAnimation(.spring(response: viewModel.springResponse, dampingFraction: viewModel.springDamping)) {
            viewModel.onTapped?()
          }
        } else {
          withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.onTapped?()
          }
        }
      }
  }
}
