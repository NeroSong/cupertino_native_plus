import FlutterMacOS
import Cocoa

// NOTE: SVG rendering is intentionally NOT supported on macOS.
// We deliberately avoid bundling SVGKit (or any SVG dependency) here to keep
// the macOS plugin lightweight. Raster formats (PNG/JPG) and SF Symbols are
// fully supported. SVG inputs from Dart will fall through to nil and the
// caller is expected to provide a raster fallback.
class CupertinoIconNSView: NSView {
  private let channel: FlutterMethodChannel
  private let imageView: NSImageView

  private var name: String = ""
  private var customIconBytes: Data?
  private var assetPath: String?
  private var imageData: Data?
  private var imageFormat: String?
  private var iconScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
  private var isDark: Bool = false
  private var size: CGFloat?
  private var color: NSColor?
  private var palette: [NSColor] = []
  private var renderingMode: String?
  private var gradientEnabled: Bool = false

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "\(ChannelConstants.viewIdCupertinoNativeIcon)_\(viewId)", binaryMessenger: messenger)
    self.imageView = NSImageView(frame: .zero)

    if let dict = args as? [String: Any] {
      if let s = dict["name"] as? String { self.name = s }
      if let data = dict["customIconBytes"] as? FlutterStandardTypedData {
        self.customIconBytes = data.data
      }
      if let path = dict["assetPath"] as? String { self.assetPath = path }
      if let data = dict["imageData"] as? FlutterStandardTypedData {
        self.imageData = data.data
      }
      if let format = dict["imageFormat"] as? String { self.imageFormat = format }
      if let b = dict["isDark"] as? NSNumber { self.isDark = b.boolValue }
      if let style = dict["style"] as? [String: Any] {
        if let v = style["iconSize"] as? NSNumber { self.size = CGFloat(truncating: v) }
        if let v = style["iconColor"] as? NSNumber { self.color = ImageUtils.colorFromARGB(v.intValue) }
        if let arr = style["iconPaletteColors"] as? [NSNumber] { self.palette = arr.map { ImageUtils.colorFromARGB($0.intValue) } }
        if let mode = style["iconRenderingMode"] as? String { self.renderingMode = mode }
        if let g = style["iconGradientEnabled"] as? NSNumber { self.gradientEnabled = g.boolValue }
      }
    }

    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.imageScaling = .scaleProportionallyUpOrDown
    addSubview(imageView)
    NSLayoutConstraint.activate([
      imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
      imageView.topAnchor.constraint(equalTo: topAnchor),
      imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])

    rebuild()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "getIntrinsicSize":
        if let img = self.imageView.image {
          result(["width": Double(img.size.width), "height": Double(img.size.height)])
        } else {
          result(["width": 0.0, "height": 0.0])
        }
      case "setSymbol":
        if let args = call.arguments as? [String: Any] {
          // Mirror iOS priority: imageData > assetPath > customIconBytes > SF Symbol
          if let assetPath = args["assetPath"] as? String, !assetPath.isEmpty {
            self.assetPath = assetPath
            self.imageData = nil
            self.imageFormat = nil
          } else if let imageData = args["imageData"] as? FlutterStandardTypedData {
            self.imageData = imageData.data
            self.imageFormat = args["imageFormat"] as? String
            self.assetPath = nil
          } else if let name = args["name"] as? String {
            // Fallback to SF Symbol
            self.name = name
            self.assetPath = nil
            self.imageData = nil
            self.imageFormat = nil
          }
          self.rebuild()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing name", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if let v = args["iconSize"] as? NSNumber { self.size = CGFloat(truncating: v) }
          if let v = args["iconColor"] as? NSNumber { self.color = ImageUtils.colorFromARGB(v.intValue) }
          if let arr = args["iconPaletteColors"] as? [NSNumber] { self.palette = arr.map { ImageUtils.colorFromARGB($0.intValue) } }
          if let mode = args["iconRenderingMode"] as? String { self.renderingMode = mode }
          if let g = args["iconGradientEnabled"] as? NSNumber { self.gradientEnabled = g.boolValue }
          // Image source updates (priority matches iOS)
          if let assetPath = args["assetPath"] as? String, !assetPath.isEmpty {
            self.assetPath = assetPath
            self.imageData = nil
            self.imageFormat = nil
          } else if let imageData = args["imageData"] as? FlutterStandardTypedData {
            self.imageData = imageData.data
            self.imageFormat = args["imageFormat"] as? String
            self.assetPath = nil
          } else if let n = args["name"] as? String {
            self.name = n
            self.assetPath = nil
            self.imageData = nil
            self.imageFormat = nil
          }
          self.rebuild()
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { return nil }

  private func rebuild() {
    var img: NSImage? = nil

    // Priority: imageData > assetPath > customIconBytes > SF Symbol (mirrors iOS)
    if let data = imageData {
      // Raw image data (PNG/JPG; SVG returns nil on macOS by design)
      img = ImageUtils.createImageFromData(data, format: imageFormat, scale: iconScale)
    } else if let path = assetPath {
      // Flutter asset path
      img = ImageUtils.loadFlutterAsset(path, scale: iconScale)
    } else if let data = customIconBytes {
      // Legacy custom icon bytes (PNG from IconData) — treated as template
      if let raster = NSImage(data: data) {
        raster.isTemplate = true
        img = raster
      }
    } else if !name.isEmpty {
      // SF Symbol
      img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    guard var image = img else { imageView.image = nil; return }

    // Apply size via SymbolConfiguration when available (mirrors iOS).
    // iconScale governs the DPI / point scale of the rendered glyph and is
    // forwarded to the raster loaders above via `scale:`.
    if let s = size {
      if #available(macOS 12.0, *) {
        let cfg = NSImage.SymbolConfiguration(pointSize: s, weight: .regular)
        if let newImg = image.withSymbolConfiguration(cfg) { image = newImg }
      }
    }

    if let mode = renderingMode {
      switch mode {
      case "monochrome":
        if let c = color {
          image = image.tinted(with: c)
        } else {
          // Match iOS: monochrome default falls back to black tint
          image = image.tinted(with: .black)
        }
      case "hierarchical":
        if #available(macOS 12.0, *), let c = color {
          let cfg = NSImage.SymbolConfiguration(hierarchicalColor: c)
          if let newImg = image.withSymbolConfiguration(cfg) { image = newImg }
        }
      case "palette":
        if #available(macOS 12.0, *), !palette.isEmpty {
          let cfg = NSImage.SymbolConfiguration(paletteColors: palette)
          if let newImg = image.withSymbolConfiguration(cfg) { image = newImg }
        }
      case "multicolor":
        if #available(macOS 12.0, *) {
          let cfg = NSImage.SymbolConfiguration.preferringMulticolor()
          if let newImg = image.withSymbolConfiguration(cfg) { image = newImg }
        }
      default:
        break
      }
    } else if let c = color {
      image = image.tinted(with: c)
    } else {
      // Match iOS: when neither color nor renderingMode is provided, default
      // to a black tint instead of system tint (blue). Keeps cross-platform
      // visual parity with the iOS CupertinoIconPlatformView fallback.
      image = image.tinted(with: .black)
    }

    if gradientEnabled {
      // Future: prefer built-in gradient when available on newer macOS versions.
      // if #available(macOS 15.0, *) { /* NSImage.SymbolConfiguration.preferringGradient() if/when shipped */ }
    }

    imageView.image = image
  }

}
