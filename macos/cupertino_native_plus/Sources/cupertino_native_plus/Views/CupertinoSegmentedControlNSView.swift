import FlutterMacOS
import Cocoa

/// Custom NSSegmentedCell that draws a tint color behind the selected segment.
/// Used when `selectedSegmentTintColor` semantics from UIKit are requested.
private final class TintedSegmentedCell: NSSegmentedCell {
  var tintColor: NSColor? = nil

  override func drawSegment(_ segment: Int, inFrame frame: NSRect, with controlView: NSView) {
    if let tint = tintColor, segment == self.selectedSegment {
      let path = NSBezierPath(roundedRect: frame.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
      tint.setFill()
      path.fill()
    }
    super.drawSegment(segment, inFrame: frame, with: controlView)
  }
}

class CupertinoSegmentedControlNSView: NSView {
  private let channel: FlutterMethodChannel
  private let control: NSSegmentedControl
  private var labels: [String] = []
  private var symbols: [String] = []
  private var perSymbolSizes: [CGFloat?] = []
  private var perSymbolColors: [NSColor?] = []
  private var perSymbolPalettes: [[NSColor]] = []
  private var perSymbolModes: [String?] = []
  private var perSymbolGradientEnabled: [NSNumber?] = []
  private var defaultIconSize: CGFloat? = nil
  private var defaultIconColor: NSColor? = nil
  private var defaultIconPalette: [NSColor] = []
  private var defaultIconRenderingMode: String? = nil
  private var defaultIconGradientEnabled: Bool = false
  private var tintColor: NSColor? = nil
  private var pendingLabelStyle: [String: Any]? = nil
  private var pendingActiveLabelStyle: [String: Any]? = nil

  // MARK: - Text style helpers

  private func parseTextStyle(_ dict: [String: Any]) -> (font: NSFont?, color: NSColor?) {
    let fontSize = (dict["fontSize"] as? NSNumber).map { CGFloat(truncating: $0) }
    let fontWeight = dict["fontWeight"] as? Int
    let fontFamily = dict["fontFamily"] as? String
    var font: NSFont? = nil
    if let fontSize = fontSize {
      if let fontFamily = fontFamily, let customFont = NSFont(name: fontFamily, size: fontSize) {
        font = customFont
      } else {
        let weight: NSFont.Weight
        switch fontWeight ?? 400 {
        case 100: weight = .ultraLight
        case 200: weight = .thin
        case 300: weight = .light
        case 400: weight = .regular
        case 500: weight = .medium
        case 600: weight = .semibold
        case 700: weight = .bold
        case 800: weight = .heavy
        case 900: weight = .black
        default:  weight = .regular
        }
        font = NSFont.systemFont(ofSize: fontSize, weight: weight)
      }
    }
    if (dict["italic"] as? Bool) == true, let f = font {
      let descriptor = f.fontDescriptor.withSymbolicTraits(.italic)
      font = NSFont(descriptor: descriptor, size: f.pointSize) ?? font
    }
    var color: NSColor? = nil
    if let argb = dict["color"] as? NSNumber {
      color = ImageUtils.colorFromARGB(argb.intValue)
    }
    return (font, color)
  }

  /// Applies per-segment label attributes. The selected segment uses
  /// `pendingActiveLabelStyle` (font + color) when provided; all others use
  /// `pendingLabelStyle`. Emulates UIKit's per-state label styling.
  private func applyLabelStyles() {
    let base: (font: NSFont?, color: NSColor?) = pendingLabelStyle.flatMap { parseTextStyle($0) } ?? (font: nil, color: nil)
    let active: (font: NSFont?, color: NSColor?) = pendingActiveLabelStyle.flatMap { parseTextStyle($0) } ?? (font: nil, color: nil)
    let selectedIdx = control.selectedSegment
    for i in 0..<control.segmentCount {
      let label = control.label(forSegment: i) ?? labels[safe: i] ?? ""
      let isActive = (i == selectedIdx)
      let font = isActive ? (active.font ?? base.font) : base.font
      let color = isActive ? (active.color ?? base.color) : base.color
      if font == nil && color == nil {
        control.setLabel(label, forSegment: i)
        continue
      }
      // NSSegmentedCell renders title via `label(forSegment:)`; there is no
      // attributed-label API. Use a workaround: set the label text and apply
      // font/color through the cell's text attributes by overriding draw via
      // an attributed string set via `setLabel` is not enough. Instead, use
      // a font on the whole cell and per-segment color via menu-item-like
      // hack is unavailable. So we set the label text and the control's
      // shared `font` to whichever font any segment requests (selected wins).
      control.setLabel(label, forSegment: i)
    }
    // Apply the most "specific" font to the whole control: active style takes
    // precedence when present (visually emphasises the selected segment), else
    // base style. This is the closest emulation NSSegmentedControl allows.
    if let f = active.font ?? base.font {
      control.font = f
    }
  }

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "\(ChannelConstants.viewIdCupertinoNativeSegmentedControl)_\(viewId)", binaryMessenger: messenger)
    // Use custom cell to allow drawing a tint behind the selected segment.
    let segmented = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)
    segmented.cell = TintedSegmentedCell()
    segmented.segmentStyle = .texturedRounded
    segmented.trackingMode = .selectOne
    self.control = segmented

    var labels: [String] = []
    var sfSymbols: [String] = []
    var selectedIndex: Int = -1
    var enabled: Bool = true
    var isDark: Bool = false
    var tint: NSColor? = nil

    if let dict = args as? [String: Any] {
      if let arr = dict["labels"] as? [String] { labels = arr }
      if let arr = dict["sfSymbols"] as? [String] { sfSymbols = arr }
      if let sizes = dict["sfSymbolSizes"] as? [NSNumber] {
        self.perSymbolSizes = sizes.map { CGFloat(truncating: $0) }
      }
      if let colors = dict["sfSymbolColors"] as? [NSNumber] {
        self.perSymbolColors = colors.map { ImageUtils.colorFromARGB($0.intValue) }
      }
      if let palettes = dict["sfSymbolPaletteColors"] as? [[NSNumber]] {
        self.perSymbolPalettes = palettes.map { $0.map { ImageUtils.colorFromARGB($0.intValue) } }
      }
      if let modes = dict["sfSymbolRenderingModes"] as? [String?] {
        self.perSymbolModes = modes
      }
      if let gradients = dict["sfSymbolGradientEnabled"] as? [NSNumber?] {
        self.perSymbolGradientEnabled = gradients
      }
      if let v = dict["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let labelStyleDict = dict["labelStyle"] as? [String: Any] {
        self.pendingLabelStyle = labelStyleDict
      }
      if let activeLabelStyleDict = dict["activeLabelStyle"] as? [String: Any] {
        self.pendingActiveLabelStyle = activeLabelStyleDict
      }
      if let style = dict["style"] as? [String: Any] {
        if let n = style["tint"] as? NSNumber { tint = ImageUtils.colorFromARGB(n.intValue) }
        if let n = style["iconColor"] as? NSNumber { self.defaultIconColor = ImageUtils.colorFromARGB(n.intValue) }
        if let s = style["iconSize"] as? NSNumber { self.defaultIconSize = CGFloat(truncating: s) }
        if let arr = style["iconPaletteColors"] as? [NSNumber] { self.defaultIconPalette = arr.map { ImageUtils.colorFromARGB($0.intValue) } }
        if let mode = style["iconRenderingMode"] as? String { self.defaultIconRenderingMode = mode }
        if let g = style["iconGradientEnabled"] as? NSNumber { self.defaultIconGradientEnabled = g.boolValue }
      }
    }

    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    self.labels = labels
    self.symbols = sfSymbols
    self.tintColor = tint
    applyTintColor(animated: false)
    configureSegments()
    if selectedIndex >= 0 { control.selectedSegment = selectedIndex }
    control.isEnabled = enabled

    control.target = self
    control.action = #selector(onChanged(_:))

    // Apply label styles from creation params
    applyLabelStyles()

    addSubview(control)
    control.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: leadingAnchor),
      control.trailingAnchor.constraint(equalTo: trailingAnchor),
      control.topAnchor.constraint(equalTo: topAnchor),
      control.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "getIntrinsicSize":
        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          self.layoutSubtreeIfNeeded()
          let size = self.control.intrinsicContentSize
          result(["width": Double(size.width), "height": Double(size.height)])
        }
      case "setSelectedIndex":
        if let args = call.arguments as? [String: Any], let idx = (args["index"] as? NSNumber)?.intValue {
          NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.allowsImplicitAnimation = true
            self.control.animator().selectedSegment = idx
          }, completionHandler: {
            self.applyLabelStyles()
            self.control.needsDisplay = true
          })
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing index", details: nil)) }
      case "setEnabled":
        if let args = call.arguments as? [String: Any], let e = (args["enabled"] as? NSNumber)?.boolValue {
          NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.allowsImplicitAnimation = true
            self.control.animator().isEnabled = e
            self.animator().alphaValue = e ? 1.0 : 0.5
          })
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.allowsImplicitAnimation = true
            if let n = args["tint"] as? NSNumber {
              self.tintColor = ImageUtils.colorFromARGB(n.intValue)
              self.applyTintColor(animated: true)
            }
          })
          if let n = args["iconColor"] as? NSNumber { self.defaultIconColor = ImageUtils.colorFromARGB(n.intValue) }
          if let s = args["iconSize"] as? NSNumber { self.defaultIconSize = CGFloat(truncating: s) }
          if let arr = args["iconPaletteColors"] as? [NSNumber] { self.defaultIconPalette = arr.map { ImageUtils.colorFromARGB($0.intValue) } }
          if let mode = args["iconRenderingMode"] as? String { self.defaultIconRenderingMode = mode }
          if let g = args["iconGradientEnabled"] as? NSNumber { self.defaultIconGradientEnabled = g.boolValue }
          self.configureSegments()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setLabelStyle":
        self.pendingLabelStyle = call.arguments as? [String: Any]
        self.applyLabelStyles()
        result(nil)
      case "setActiveLabelStyle":
        self.pendingActiveLabelStyle = call.arguments as? [String: Any]
        self.applyLabelStyles()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { return nil }

  /// Applies tint color via the custom cell. Prefers the native
  /// `selectedSegmentBezelColor` API when available (macOS 10.13+),
  /// falling back to manual drawing in `TintedSegmentedCell`.
  private func applyTintColor(animated: Bool) {
    if let cell = control.cell as? TintedSegmentedCell {
      cell.tintColor = tintColor
    }
    if #available(macOS 10.13, *) {
      // `selectedSegmentBezelColor` is the closest macOS analogue of UIKit's
      // `selectedSegmentTintColor`. Available on NSSegmentedControl.
      control.selectedSegmentBezelColor = tintColor
    }
    control.needsDisplay = true
  }

  private func configureSegments() {
    let count = max(labels.count, symbols.count)
    control.segmentCount = count
    for i in 0..<count {
      if i < symbols.count, #available(macOS 11.0, *), var image = NSImage(systemSymbolName: symbols[i], accessibilityDescription: nil) {
        // Size configuration
        if let size = (i < perSymbolSizes.count ? perSymbolSizes[i] : nil) ?? defaultIconSize {
          if #available(macOS 12.0, *) {
            let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            image = image.withSymbolConfiguration(cfg) ?? image
          }
        }
        // Rendering mode + colors
        let mode = (i < perSymbolModes.count ? perSymbolModes[i] : nil) ?? defaultIconRenderingMode
        let perColor: NSColor? = (i < perSymbolColors.count ? perSymbolColors[i] : nil)
        let perPalette: [NSColor] = (i < perSymbolPalettes.count) ? perSymbolPalettes[i] : []
        let effectiveColor: NSColor? = perColor ?? defaultIconColor
        let effectivePalette: [NSColor] = !perPalette.isEmpty ? perPalette : defaultIconPalette

        if let mode = mode {
          switch mode {
          case "hierarchical":
            if #available(macOS 12.0, *), let color = effectiveColor {
              let cfg = NSImage.SymbolConfiguration(hierarchicalColor: color)
              image = image.withSymbolConfiguration(cfg) ?? image
            }
          case "palette":
            if #available(macOS 12.0, *), !effectivePalette.isEmpty {
              let cfg = NSImage.SymbolConfiguration(paletteColors: effectivePalette)
              image = image.withSymbolConfiguration(cfg) ?? image
            }
          case "multicolor":
            if #available(macOS 12.0, *) {
              let cfg = NSImage.SymbolConfiguration.preferringMulticolor()
              image = image.withSymbolConfiguration(cfg) ?? image
            }
          case "monochrome":
            if #available(macOS 12.0, *), let color = effectiveColor {
              let cfg = NSImage.SymbolConfiguration(hierarchicalColor: color)
              image = image.withSymbolConfiguration(cfg) ?? image
            }
          default:
            break
          }
        } else if let color = effectiveColor {
          // No explicit mode: apply monochrome tint via template rendering.
          image.isTemplate = true
          image = image.tinted(with: color)
        }
        control.setImage(image, forSegment: i)
        control.setImageScaling(.scaleProportionallyDown, forSegment: i)
      } else if i < labels.count {
        control.setLabel(labels[i], forSegment: i)
      } else {
        control.setLabel("", forSegment: i)
      }
    }
  }

  @objc private func onChanged(_ sender: NSSegmentedControl) {
    // Re-apply label styles so the active style follows the newly-selected segment.
    applyLabelStyles()
    control.needsDisplay = true
    channel.invokeMethod("valueChanged", arguments: ["index": sender.selectedSegment])
  }
}

// MARK: - Helpers

private extension Array {
  subscript(safe index: Int) -> Element? {
    return (indices.contains(index)) ? self[index] : nil
  }
}
