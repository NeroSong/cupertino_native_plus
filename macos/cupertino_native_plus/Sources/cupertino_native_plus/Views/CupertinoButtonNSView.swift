import FlutterMacOS
import Cocoa
import SwiftUI

// MARK: - ViewModel

@available(macOS 26.0, *)
final class CupertinoButtonViewModel: ObservableObject {
  @Published var title: String?
  @Published var iconConfig: IconConfig?
  @Published var theme: CNButtonTheme
  @Published var style: String
  @Published var isEnabled: Bool
  @Published var glassEffectUnionId: String?
  @Published var glassEffectId: String?
  @Published var glassEffectInteractive: Bool
  @Published var config: GlassButtonConfig
  @Published var imagePlacement: String
  @Published var contentAlignment: String

  init(
    title: String?,
    iconConfig: IconConfig?,
    theme: CNButtonTheme,
    style: String,
    isEnabled: Bool,
    glassEffectUnionId: String?,
    glassEffectId: String?,
    glassEffectInteractive: Bool,
    config: GlassButtonConfig,
    imagePlacement: String,
    contentAlignment: String = "center"
  ) {
    self.title = title
    self.iconConfig = iconConfig
    self.theme = theme
    self.style = style
    self.isEnabled = isEnabled
    self.glassEffectUnionId = glassEffectUnionId
    self.glassEffectId = glassEffectId
    self.glassEffectInteractive = glassEffectInteractive
    self.config = config
    self.imagePlacement = imagePlacement
    self.contentAlignment = contentAlignment
  }
}

// MARK: - Platform View

class CupertinoButtonNSView: NSView {
  private let channel: FlutterMethodChannel
  private var button: NSButton?
  private var hostingController: NSHostingController<AnyView>?
  private var isEnabled: Bool = true
  private var currentButtonStyle: String = "automatic"
  private var usesSwiftUI: Bool = false
  private var makeRound: Bool = false
  private var currentTint: NSColor?

  // NSButton padding constraints (for non-SwiftUI path)
  private var buttonLeading: NSLayoutConstraint?
  private var buttonTrailing: NSLayoutConstraint?
  private var buttonTop: NSLayoutConstraint?
  private var buttonBottom: NSLayoutConstraint?
  private var buttonMinHeight: NSLayoutConstraint?
  private var buttonFixedWidth: NSLayoutConstraint?

  // Holds CupertinoButtonViewModel when macOS 26+; typed as AnyObject to avoid @available restriction.
  private var _buttonViewModel: AnyObject?

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "\(ChannelConstants.viewIdCupertinoNativeButton)_\(viewId)", binaryMessenger: messenger)
    super.init(frame: .zero)

    var title: String? = nil
    var iconName: String? = nil
    var customIconBytes: Data? = nil
    var assetPath: String? = nil
    var imageData: Data? = nil
    var imageFormat: String? = nil
    var xcassetName: String? = nil
    var iconSize: CGFloat? = nil
    var iconColor: NSColor? = nil
    var makeRound: Bool = false
    var buttonStyle: String = "automatic"
    var isDark: Bool = false
    var tint: NSColor? = nil
    var enabled: Bool = true
    var iconMode: String? = nil
    var iconPalette: [NSNumber] = []
    let iconScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
    var glassEffectUnionId: String? = nil
    var glassEffectId: String? = nil
    var glassEffectInteractive: Bool = false
    var imagePlacement: String = "leading"
    var contentAlignment: String = "center"
    var borderRadius: CGFloat? = nil
    var paddingTop: CGFloat? = nil
    var paddingBottom: CGFloat? = nil
    var paddingLeft: CGFloat? = nil
    var paddingRight: CGFloat? = nil
    var paddingHorizontal: CGFloat? = nil
    var paddingVertical: CGFloat? = nil
    var minHeight: CGFloat? = nil
    var imagePadding: CGFloat? = nil
    var swiftUIWidth: CGFloat? = nil
    var swiftUIExpandWidth: Bool = false

    // Build icon/theme args dicts for SwiftUI path (macOS 26+).
    var iconArgs: [String: Any] = [:]
    var themeArgs: [String: Any] = [:]

    if let dict = args as? [String: Any] {
      if let t = dict["buttonTitle"] as? String { title = t }
      if let data = dict["buttonCustomIconBytes"] as? FlutterStandardTypedData {
        customIconBytes = data.data
      }
      if let name = dict["buttonXcassetName"] as? String { xcassetName = name }
      if let ap = dict["buttonAssetPath"] as? String { assetPath = ap }
      if let data = dict["buttonImageData"] as? FlutterStandardTypedData {
        imageData = data.data
      }
      if let f = dict["buttonImageFormat"] as? String { imageFormat = f }
      if let s = dict["buttonIconName"] as? String { iconName = s }
      if let s = dict["buttonIconSize"] as? NSNumber { iconSize = CGFloat(truncating: s) }
      if let c = dict["buttonIconColor"] as? NSNumber {
        iconColor = ImageUtils.colorFromARGB(c.intValue)
      }
      if let r = dict["round"] as? NSNumber {
        makeRound = r.boolValue
        self.makeRound = makeRound
      }
      if let gueId = dict["glassEffectUnionId"] as? String { glassEffectUnionId = gueId }
      if let geId = dict["glassEffectId"] as? String { glassEffectId = geId }
      if let geInteractive = dict["glassEffectInteractive"] as? NSNumber {
        glassEffectInteractive = geInteractive.boolValue
      }
      if let bs = dict["buttonStyle"] as? String { buttonStyle = bs }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any], let n = style["tint"] as? NSNumber {
        tint = ImageUtils.colorFromARGB(n.intValue)
      }
      if let e = dict["enabled"] as? NSNumber { enabled = e.boolValue }
      if let m = dict["buttonIconRenderingMode"] as? String { iconMode = m }
      if let pal = dict["buttonIconPaletteColors"] as? [NSNumber] { iconPalette = pal }
      if let br = dict["borderRadius"] as? NSNumber { borderRadius = CGFloat(truncating: br) }
      if let pt = dict["paddingTop"] as? NSNumber { paddingTop = CGFloat(truncating: pt) }
      if let pb = dict["paddingBottom"] as? NSNumber { paddingBottom = CGFloat(truncating: pb) }
      if let pl = dict["paddingLeft"] as? NSNumber { paddingLeft = CGFloat(truncating: pl) }
      if let pr = dict["paddingRight"] as? NSNumber { paddingRight = CGFloat(truncating: pr) }
      if let ph = dict["paddingHorizontal"] as? NSNumber {
        paddingHorizontal = CGFloat(truncating: ph)
      }
      if let pv = dict["paddingVertical"] as? NSNumber { paddingVertical = CGFloat(truncating: pv) }
      if let mh = dict["minHeight"] as? NSNumber { minHeight = CGFloat(truncating: mh) }
      if let ip = dict["imagePadding"] as? NSNumber { imagePadding = CGFloat(truncating: ip) }
      if let imp = dict["imagePlacement"] as? String { imagePlacement = imp }
      if let ca = dict["contentAlignment"] as? String { contentAlignment = ca }
      if let bw = dict["buttonWidth"] as? NSNumber { swiftUIWidth = CGFloat(truncating: bw) }
      if let ew = dict["buttonExpandWidth"] as? NSNumber { swiftUIExpandWidth = ew.boolValue }

      // Build icon args dict: pre-convert FlutterStandardTypedData → Data.
      iconArgs = dict
      for key in ["buttonImageData", "buttonCustomIconBytes"] {
        if let td = iconArgs[key] as? FlutterStandardTypedData { iconArgs[key] = td.data }
      }

      // Build flat theme dict from nested style + top-level glassMaterial + CNButtonTheme colors.
      if let style = dict["style"] as? [String: Any], let n = style["tint"] as? NSNumber {
        themeArgs["tint"] = n.intValue
      }
      if let gm = dict["glassMaterial"] as? String { themeArgs["glassMaterial"] = gm }
      for key in ["labelColor", "themeIconColor", "backgroundColor"] {
        if let n = dict[key] as? NSNumber { themeArgs[key] = n.intValue }
      }
      if let ls = dict["labelStyle"] as? [String: Any] { themeArgs["labelStyle"] = ls }
    }

    self.currentTint = tint

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    // Resolve final image up front — same priority as iOS:
    // xcasset > assetPath > imageData > customIconBytes > SF Symbol.
    // Only the AppKit fallback needs this; the SwiftUI path resolves icons via
    // GlassButtonSwiftUI → CNIcon. We still compute it here so warm-cache image
    // loads happen once on the init thread.
    let finalImage: NSImage? = Self.resolveImage(
      xcassetName: xcassetName,
      assetPath: assetPath,
      imageData: imageData,
      imageFormat: imageFormat,
      customIconBytes: customIconBytes,
      iconName: iconName,
      iconSize: iconSize,
      iconColor: iconColor,
      iconMode: iconMode,
      iconPalette: iconPalette,
      iconScale: iconScale
    )

    // Mirror iOS gate: macOS 26+ always uses SwiftUI path (full glass + parity).
    if #available(macOS 26.0, *) {
      usesSwiftUI = true
      setupSwiftUIButton(
        title: title,
        iconArgs: iconArgs,
        themeArgs: themeArgs,
        style: buttonStyle,
        enabled: enabled,
        glassEffectUnionId: glassEffectUnionId,
        glassEffectId: glassEffectId,
        glassEffectInteractive: glassEffectInteractive,
        borderRadius: borderRadius,
        paddingTop: paddingTop,
        paddingBottom: paddingBottom,
        paddingLeft: paddingLeft,
        paddingRight: paddingRight,
        paddingHorizontal: paddingHorizontal,
        paddingVertical: paddingVertical,
        minHeight: minHeight ?? 44.0,
        spacing: imagePadding ?? 8.0,
        imagePlacement: imagePlacement,
        contentAlignment: contentAlignment,
        width: swiftUIWidth,
        expandWidth: swiftUIExpandWidth
      )
    } else {
      // Legacy AppKit path for pre-macOS 26 systems.
      setupAppKitButton(
        title: title,
        finalImage: finalImage,
        buttonStyle: buttonStyle,
        round: makeRound,
        tint: tint,
        enabled: enabled,
        imagePlacement: imagePlacement,
        imagePadding: imagePadding,
        paddingTop: paddingTop,
        paddingBottom: paddingBottom,
        paddingLeft: paddingLeft,
        paddingRight: paddingRight,
        paddingHorizontal: paddingHorizontal,
        paddingVertical: paddingVertical,
        borderRadius: borderRadius,
        minHeight: minHeight,
        buttonWidth: swiftUIWidth
      )
    }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "getIntrinsicSize":
        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          if self.usesSwiftUI {
            if #available(macOS 26.0, *), let hc = self.hostingController {
              // Mirror iOS measurement strategy: temporarily disable expandWidth
              // so sizeThatFits returns the button's intrinsic content width
              // instead of the proposed width.
              if let vm = self.buttonViewModel, vm.config.expandWidth {
                let original = vm.config
                vm.config = GlassButtonConfig(
                  borderRadius: original.borderRadius,
                  padding: original.padding,
                  minHeight: original.minHeight,
                  spacing: original.spacing,
                  width: original.width,
                  expandWidth: false,
                  contentAlignment: original.contentAlignment
                )
                hc.view.needsLayout = true
                hc.view.layoutSubtreeIfNeeded()
                let screen = NSScreen.main?.frame.size ?? CGSize(width: 2000, height: 2000)
                let proposed = CGSize(width: screen.width * 2, height: screen.height)
                let sz = hc.sizeThatFits(in: proposed)
                vm.config = original
                let validWidth = sz.width > 0 && sz.width < proposed.width * 0.9
                let w = validWidth ? Double(ceil(sz.width)) : 80.0
                let h = sz.height > 0 ? Double(ceil(sz.height)) : 44.0
                result(["width": w, "height": h])
                return
              }
              hc.view.needsLayout = true
              hc.view.layoutSubtreeIfNeeded()
              let screen = NSScreen.main?.frame.size ?? CGSize(width: 2000, height: 2000)
              let proposed = CGSize(width: screen.width * 2, height: screen.height)
              let sz = hc.sizeThatFits(in: proposed)
              let validWidth = sz.width > 0 && sz.width < proposed.width * 0.9
              let w = validWidth ? Double(ceil(sz.width)) : 80.0
              let h = sz.height > 0 ? Double(ceil(sz.height)) : 44.0
              result(["width": w, "height": h])
            } else {
              result(["width": 80.0, "height": 44.0])
            }
          } else if let button = self.button {
            self.layoutSubtreeIfNeeded()
            let s = button.intrinsicContentSize
            result(["width": Double(s.width), "height": Double(s.height)])
          } else {
            result(["width": 80.0, "height": 32.0])
          }
        }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if let n = args["tint"] as? NSNumber {
            self.currentTint = ImageUtils.colorFromARGB(n.intValue)
          }
          if self.usesSwiftUI {
            if #available(macOS 26.0, *), let vm = self.buttonViewModel {
              if let bs = args["buttonStyle"] as? String { vm.style = bs }
              // Merge incoming color overrides into the existing theme.
              let existing = vm.theme
              func argbToColor(_ n: NSNumber) -> Color {
                let v = n.intValue
                let a = Double((v >> 24) & 0xFF) / 255.0
                let r = Double((v >> 16) & 0xFF) / 255.0
                let g = Double((v >> 8)  & 0xFF) / 255.0
                let b = Double( v        & 0xFF) / 255.0
                return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
              }
              vm.theme = CNButtonTheme(
                tint:            (args["tint"]            as? NSNumber).map(argbToColor) ?? existing.tint,
                labelColor:      (args["labelColor"]      as? NSNumber).map(argbToColor) ?? existing.labelColor,
                iconColor:       (args["themeIconColor"]  as? NSNumber).map(argbToColor) ?? existing.iconColor,
                backgroundColor: (args["backgroundColor"] as? NSNumber).map(argbToColor) ?? existing.backgroundColor,
                glassMaterial:   existing.glassMaterial,
                labelFont:       existing.labelFont
              )
              if let gei = args["glassEffectInteractive"] as? NSNumber {
                vm.glassEffectInteractive = gei.boolValue
              }
            }
          } else if let button = self.button {
            if #available(macOS 10.14, *), let n = args["tint"] as? NSNumber {
              let color = ImageUtils.colorFromARGB(n.intValue)
              if ["filled", "borderedProminent", "prominentGlass"].contains(self.currentButtonStyle) {
                button.bezelColor = color
                button.contentTintColor = .white
              } else {
                button.contentTintColor = color
              }
            }
            if let bs = args["buttonStyle"] as? String {
              self.currentButtonStyle = bs
              self.applyAppKitButtonStyle(button: button, buttonStyle: bs, round: self.makeRound)
            }
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setButtonTitle":
        if let args = call.arguments as? [String: Any], let t = args["title"] as? String {
          if self.usesSwiftUI {
            if #available(macOS 26.0, *) {
              self.buttonViewModel?.title = t
            }
          } else if let button = self.button {
            button.title = t
            button.image = nil
            button.imagePosition = .noImage
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing title", details: nil)) }
      case "setImagePlacement":
        if let args = call.arguments as? [String: Any], let placement = args["placement"] as? String {
          if self.usesSwiftUI {
            if #available(macOS 26.0, *) {
              self.buttonViewModel?.imagePlacement = placement
            }
          } else if let button = self.button {
            switch placement {
            case "leading": button.imagePosition = .imageLeft
            case "trailing": button.imagePosition = .imageRight
            case "top": button.imagePosition = .imageAbove
            case "bottom": button.imagePosition = .imageBelow
            default: button.imagePosition = .imageLeft
            }
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing placement", details: nil)) }
      case "setImagePadding":
        if let args = call.arguments as? [String: Any],
           let padding = (args["padding"] as? NSNumber).map({ CGFloat(truncating: $0) }) {
          if self.usesSwiftUI {
            if #available(macOS 26.0, *), let vm = self.buttonViewModel {
              let old = vm.config
              vm.config = GlassButtonConfig(
                borderRadius: old.borderRadius,
                padding: old.padding,
                minHeight: old.minHeight,
                spacing: padding,
                width: old.width,
                expandWidth: old.expandWidth,
                contentAlignment: old.contentAlignment
              )
            }
          }
          // AppKit NSButton has no direct imagePadding; ignore silently for non-SwiftUI.
          result(nil)
        } else {
          if self.usesSwiftUI {
            if #available(macOS 26.0, *), let vm = self.buttonViewModel {
              let old = vm.config
              vm.config = GlassButtonConfig(
                borderRadius: old.borderRadius,
                padding: old.padding,
                minHeight: old.minHeight,
                spacing: 8.0,
                width: old.width,
                expandWidth: old.expandWidth,
                contentAlignment: old.contentAlignment
              )
            }
          }
          result(nil)
        }
      case "setTextStyle":
        if self.usesSwiftUI {
          if #available(macOS 26.0, *), let vm = self.buttonViewModel {
            let labelFont: Font? = {
              guard let d = call.arguments as? [String: Any] else { return nil }
              let size = (d["fontSize"] as? NSNumber).map { CGFloat(truncating: $0) }
              let weightInt = d["fontWeight"] as? Int
              let family = d["fontFamily"] as? String
              let w: Font.Weight
              switch weightInt ?? 400 {
              case 100: w = .ultraLight; case 200: w = .thin; case 300: w = .light
              case 400: w = .regular; case 500: w = .medium; case 600: w = .semibold
              case 700: w = .bold; case 800: w = .heavy; case 900: w = .black
              default: w = .regular
              }
              let isItalic = (d["italic"] as? Bool) == true
              var f: Font?
              if let family, let sz = size { f = .custom(family, size: sz) }
              else if let sz = size { f = .system(size: sz, weight: w) }
              if isItalic, let existing = f { return existing.italic() }
              return f
            }()
            vm.theme = CNButtonTheme(
              tint: vm.theme.tint, labelColor: vm.theme.labelColor,
              iconColor: vm.theme.iconColor, backgroundColor: vm.theme.backgroundColor,
              glassMaterial: vm.theme.glassMaterial, labelFont: labelFont
            )
          }
          result(nil)
        } else if let args = call.arguments as? [String: Any] {
          let color = (args["color"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
          let fontSize = (args["fontSize"] as? NSNumber).map { CGFloat(truncating: $0) }
          let fontWeight = args["fontWeight"] as? Int
          let fontFamily = args["fontFamily"] as? String

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
              default: weight = .regular
              }
              font = NSFont.systemFont(ofSize: fontSize, weight: weight)
            }
          }
          if (args["italic"] as? Bool) == true, let f = font {
            let descriptor = f.fontDescriptor.withSymbolicTraits(.italic)
            font = NSFont(descriptor: descriptor, size: f.pointSize) ?? font
          }

          if let button = self.button, !button.title.isEmpty {
            let title = button.title
            let attrString = NSMutableAttributedString(string: title)
            if let font = font {
              attrString.addAttribute(.font, value: font, range: NSRange(location: 0, length: title.count))
            }
            if let color = color {
              attrString.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: title.count))
            }
            button.attributedTitle = attrString
          }
          result(nil)
        } else {
          if let button = self.button {
            button.attributedTitle = NSAttributedString(string: button.title)
          }
          result(nil)
        }
      case "setHorizontalPadding":
        if let args = call.arguments as? [String: Any],
           let padding = (args["padding"] as? NSNumber).map({ CGFloat(truncating: $0) }) {
          if self.usesSwiftUI {
            if #available(macOS 26.0, *), let vm = self.buttonViewModel {
              let old = vm.config
              vm.config = GlassButtonConfig(
                borderRadius: old.borderRadius,
                padding: EdgeInsets(
                  top: old.padding.top,
                  leading: padding,
                  bottom: old.padding.bottom,
                  trailing: padding
                ),
                minHeight: old.minHeight,
                spacing: old.spacing,
                width: old.width,
                expandWidth: old.expandWidth,
                contentAlignment: old.contentAlignment
              )
            }
          } else if self.button != nil {
            self.buttonLeading?.constant = padding
            self.buttonTrailing?.constant = -padding
          }
          result(nil)
        } else {
          if self.usesSwiftUI {
            if #available(macOS 26.0, *), let vm = self.buttonViewModel {
              let old = vm.config
              vm.config = GlassButtonConfig(
                borderRadius: old.borderRadius,
                padding: EdgeInsets(top: old.padding.top, leading: 0, bottom: old.padding.bottom, trailing: 0),
                minHeight: old.minHeight,
                spacing: old.spacing,
                width: old.width,
                expandWidth: old.expandWidth,
                contentAlignment: old.contentAlignment
              )
            }
          } else if self.button != nil {
            self.buttonLeading?.constant = 0
            self.buttonTrailing?.constant = 0
          }
          result(nil)
        }
      case "setEnabled":
        if let args = call.arguments as? [String: Any], let e = args["enabled"] as? NSNumber {
          self.isEnabled = e.boolValue
          if self.usesSwiftUI {
            if #available(macOS 26.0, *) {
              self.buttonViewModel?.isEnabled = e.boolValue
            }
          } else if let button = self.button {
            button.isEnabled = self.isEnabled
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setButtonIcon":
        if let args = call.arguments as? [String: Any] {
          // Build full priority chain identical to iOS:
          // xcasset > assetPath > imageData > customIconBytes > SF Symbol.
          let resolvedImage = Self.resolveImageFromArgs(args)

          if self.usesSwiftUI {
            if #available(macOS 26.0, *), let vm = self.buttonViewModel {
              var iconArgs = args
              for key in ["buttonImageData", "buttonCustomIconBytes"] {
                if let td = iconArgs[key] as? FlutterStandardTypedData { iconArgs[key] = td.data }
              }
              let iconConfig = IconConfig.from(dict: iconArgs)
              vm.iconConfig = iconConfig.hasIcon ? iconConfig : nil
            }
          } else if let button = self.button, let image = resolvedImage {
            button.image = image
            button.title = ""
            button.imagePosition = .imageOnly
            if let r = args["round"] as? NSNumber, r.boolValue {
              button.bezelStyle = .circular
            }
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing icon args", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setPressed":
        if let args = call.arguments as? [String: Any], let p = args["pressed"] as? NSNumber {
          if self.usesSwiftUI {
            // SwiftUI Button manages its own pressed state. Honor request as a
            // visual hint via alpha — AppKit cannot reach into the SwiftUI Button.
            self.alphaValue = p.boolValue ? 0.7 : 1.0
          } else if let button = self.button {
            // NSButton has no public isHighlighted setter; use highlight(_:) which
            // toggles the highlighted bezel/title rendering. Fall back to alpha
            // if the visual treatment is not visible (e.g. borderless plain).
            button.highlight(p.boolValue)
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing pressed", details: nil)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  required init?(coder: NSCoder) { return nil }

  @objc private func onPressed(_ sender: NSButton?) {
    guard isEnabled else { return }
    channel.invokeMethod("pressed", arguments: nil)
  }

  // MARK: - ViewModel accessor

  @available(macOS 26.0, *)
  private var buttonViewModel: CupertinoButtonViewModel? {
    _buttonViewModel as? CupertinoButtonViewModel
  }

  // MARK: - SwiftUI setup

  /// Creates the ViewModel and hosting controller once. The rootView is never replaced after this
  /// point — all state changes flow through @Published properties on the ViewModel.
  @available(macOS 26.0, *)
  private func setupSwiftUIButton(
    title: String?,
    iconArgs: [String: Any],
    themeArgs: [String: Any],
    style: String,
    enabled: Bool,
    glassEffectUnionId: String?,
    glassEffectId: String?,
    glassEffectInteractive: Bool,
    borderRadius: CGFloat?,
    paddingTop: CGFloat?,
    paddingBottom: CGFloat?,
    paddingLeft: CGFloat?,
    paddingRight: CGFloat?,
    paddingHorizontal: CGFloat?,
    paddingVertical: CGFloat?,
    minHeight: CGFloat,
    spacing: CGFloat,
    imagePlacement: String,
    contentAlignment: String,
    width: CGFloat?,
    expandWidth: Bool
  ) {
    let config = GlassButtonConfig(
      borderRadius: borderRadius,
      top: paddingTop,
      bottom: paddingBottom,
      left: paddingLeft,
      right: paddingRight,
      horizontal: paddingHorizontal,
      vertical: paddingVertical,
      minHeight: minHeight,
      spacing: spacing,
      width: width,
      expandWidth: expandWidth,
      contentAlignment: contentAlignment
    )
    let iconConfig = IconConfig.from(dict: iconArgs)
    let theme = CNButtonTheme.from(dict: themeArgs)

    let viewModel = CupertinoButtonViewModel(
      title: title,
      iconConfig: iconConfig.hasIcon ? iconConfig : nil,
      theme: theme,
      style: style,
      isEnabled: enabled,
      glassEffectUnionId: glassEffectUnionId,
      glassEffectId: glassEffectId,
      glassEffectInteractive: glassEffectInteractive,
      config: config,
      imagePlacement: imagePlacement,
      contentAlignment: contentAlignment
    )
    self._buttonViewModel = viewModel

    struct ButtonWrapperView: View {
      @Namespace private var namespace
      @ObservedObject var viewModel: CupertinoButtonViewModel
      let onPressed: () -> Void

      var body: some View {
        GlassButtonSwiftUI(
          title: viewModel.title,
          iconConfig: viewModel.iconConfig,
          theme: viewModel.theme,
          style: viewModel.style,
          isEnabled: viewModel.isEnabled,
          onPressed: onPressed,
          glassEffectUnionId: viewModel.glassEffectUnionId,
          glassEffectId: viewModel.glassEffectId,
          glassEffectInteractive: viewModel.glassEffectInteractive,
          namespace: namespace,
          config: viewModel.config,
          imagePlacement: viewModel.imagePlacement,
          contentAlignment: viewModel.contentAlignment
        )
      }
    }

    let wrapperView = ButtonWrapperView(
      viewModel: viewModel,
      onPressed: { [weak self] in self?.onPressed(nil) }
    )
    let hostingController = NSHostingController(rootView: AnyView(wrapperView))
    hostingController.view.wantsLayer = true
    hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
    self.hostingController = hostingController

    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hostingController.view)
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    DispatchQueue.main.async { [weak self, weak hostingController] in
      guard let self = self, let hostingController = hostingController else { return }
      self.needsLayout = true
      self.layoutSubtreeIfNeeded()
      hostingController.view.needsLayout = true
      hostingController.view.layoutSubtreeIfNeeded()
      DispatchQueue.main.async { [weak hostingController] in
        guard let hostingController = hostingController else { return }
        hostingController.view.needsDisplay = true
        hostingController.view.needsLayout = true
        hostingController.view.layoutSubtreeIfNeeded()
      }
    }
  }

  // MARK: - AppKit setup (pre-macOS 26 fallback)

  private func setupAppKitButton(
    title: String?,
    finalImage: NSImage?,
    buttonStyle: String,
    round: Bool,
    tint: NSColor?,
    enabled: Bool,
    imagePlacement: String,
    imagePadding: CGFloat?,
    paddingTop: CGFloat?,
    paddingBottom: CGFloat?,
    paddingLeft: CGFloat?,
    paddingRight: CGFloat?,
    paddingHorizontal: CGFloat?,
    paddingVertical: CGFloat?,
    borderRadius: CGFloat?,
    minHeight: CGFloat?,
    buttonWidth: CGFloat?
  ) {
    let nsButton = NSButton(title: title ?? "", target: self, action: #selector(onPressed(_:)))
    self.button = nsButton
    nsButton.setButtonType(.momentaryPushIn)

    switch imagePlacement {
    case "leading": nsButton.imagePosition = .imageLeft
    case "trailing": nsButton.imagePosition = .imageRight
    case "top": nsButton.imagePosition = .imageAbove
    case "bottom": nsButton.imagePosition = .imageBelow
    default: nsButton.imagePosition = .imageLeft
    }

    if let image = finalImage {
      nsButton.image = image
      if title == nil || title?.isEmpty == true {
        nsButton.imagePosition = .imageOnly
      }
    }

    applyAppKitButtonStyle(button: nsButton, buttonStyle: buttonStyle, round: round)
    currentButtonStyle = buttonStyle

    if #available(macOS 10.14, *), let c = tint {
      if ["filled", "borderedProminent", "prominentGlass"].contains(buttonStyle) {
        nsButton.bezelColor = c
        nsButton.contentTintColor = .white
      } else {
        nsButton.contentTintColor = c
      }
    }

    if let radius = borderRadius {
      nsButton.wantsLayer = true
      nsButton.layer?.cornerRadius = radius
      nsButton.layer?.masksToBounds = true
    }

    nsButton.isEnabled = enabled
    isEnabled = enabled

    // Resolve effective padding (per-side > horizontal/vertical > 0).
    let leftPad: CGFloat = paddingLeft ?? paddingHorizontal ?? 0
    let rightPad: CGFloat = paddingRight ?? paddingHorizontal ?? 0
    let topPad: CGFloat = paddingTop ?? paddingVertical ?? 0
    let bottomPad: CGFloat = paddingBottom ?? paddingVertical ?? 0

    addSubview(nsButton)
    nsButton.translatesAutoresizingMaskIntoConstraints = false
    let leading = nsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leftPad)
    let trailing = nsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -rightPad)
    let top = nsButton.topAnchor.constraint(equalTo: topAnchor, constant: topPad)
    let bottom = nsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomPad)
    NSLayoutConstraint.activate([leading, trailing, top, bottom])
    buttonLeading = leading
    buttonTrailing = trailing
    buttonTop = top
    buttonBottom = bottom

    if let mh = minHeight {
      let c = nsButton.heightAnchor.constraint(greaterThanOrEqualToConstant: mh)
      c.isActive = true
      buttonMinHeight = c
    }
    if let bw = buttonWidth {
      let c = nsButton.widthAnchor.constraint(equalToConstant: bw)
      c.isActive = true
      buttonFixedWidth = c
    }

    DispatchQueue.main.async { [weak self, weak nsButton] in
      guard let self = self, let nsButton = nsButton else { return }
      self.needsLayout = true
      self.layoutSubtreeIfNeeded()
      nsButton.needsLayout = true
      nsButton.layoutSubtreeIfNeeded()
    }
  }

  private func applyAppKitButtonStyle(button: NSButton, buttonStyle: String, round: Bool) {
    switch buttonStyle {
    case "plain":
      button.bezelStyle = .texturedRounded
      button.isBordered = false
    case "gray": button.bezelStyle = .texturedRounded
    case "tinted": button.bezelStyle = .texturedRounded
    case "bordered": button.bezelStyle = .rounded
    case "borderedProminent": button.bezelStyle = .rounded
    case "filled": button.bezelStyle = .rounded
    case "glass": button.bezelStyle = .texturedRounded
    case "prominentGlass": button.bezelStyle = .texturedRounded
    default: button.bezelStyle = .rounded
    }
    if round { button.bezelStyle = .circular }
    if buttonStyle != "plain" { button.isBordered = true }
  }

  // MARK: - Icon resolution (full iOS-parity chain)

  /// Priority: xcasset > assetPath > imageData > customIconBytes > SF Symbol.
  private static func resolveImage(
    xcassetName: String?,
    assetPath: String?,
    imageData: Data?,
    imageFormat: String?,
    customIconBytes: Data?,
    iconName: String?,
    iconSize: CGFloat?,
    iconColor: NSColor?,
    iconMode: String?,
    iconPalette: [NSNumber],
    iconScale: CGFloat
  ) -> NSImage? {
    // xcasset (highest priority): load from main bundle.
    if let name = xcassetName, !name.isEmpty {
      if let image = Bundle.main.image(forResource: name) {
        return _applyIconStyling(image: image, size: iconSize, color: iconColor)
      }
    }

    // Flutter asset path
    if let path = assetPath, !path.isEmpty {
      let detectedFormat = ImageUtils.detectImageFormat(assetPath: path, providedFormat: imageFormat)
      let iconColorARGB: Int? = iconColor.flatMap { ImageUtils.colorToARGB($0) }
      let loaded: NSImage?
      if let argb = iconColorARGB {
        loaded = ImageUtils.loadAndTintImage(
          from: path,
          iconSize: iconSize,
          iconColor: argb,
          providedFormat: imageFormat,
          scale: iconScale
        )
      } else {
        let size = iconSize.map { CGSize(width: $0, height: $0) }
        loaded = ImageUtils.loadFlutterAsset(path, size: size, format: detectedFormat, scale: iconScale)
      }
      if let image = loaded { return _applyIconStyling(image: image, size: iconSize, color: nil) }
    }

    // Raw image bytes
    if let data = imageData {
      let iconColorARGB: Int? = iconColor.flatMap { ImageUtils.colorToARGB($0) }
      let created: NSImage?
      if let argb = iconColorARGB {
        created = ImageUtils.createAndTintImage(
          from: data,
          iconSize: iconSize,
          iconColor: argb,
          providedFormat: imageFormat,
          scale: iconScale
        )
      } else {
        let size = iconSize.map { CGSize(width: $0, height: $0) }
        created = ImageUtils.createImageFromData(data, format: imageFormat, size: size, scale: iconScale)
      }
      if let image = created { return _applyIconStyling(image: image, size: iconSize, color: nil) }
    }

    // Custom raw bytes (legacy)
    if let data = customIconBytes, let image = NSImage(data: data) {
      image.isTemplate = true
      if let col = iconColor {
        return image.templateTinted(with: col)
      }
      return image
    }

    // SF Symbol fallback
    if let name = iconName, var image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
      if #available(macOS 12.0, *), let sz = iconSize {
        let cfg = NSImage.SymbolConfiguration(pointSize: sz, weight: .regular)
        image = image.withSymbolConfiguration(cfg) ?? image
      }
      if let mode = iconMode {
        switch mode {
        case "hierarchical":
          if #available(macOS 12.0, *), let c = iconColor {
            let cfg = NSImage.SymbolConfiguration(hierarchicalColor: c)
            image = image.withSymbolConfiguration(cfg) ?? image
          }
        case "palette":
          if #available(macOS 12.0, *), !iconPalette.isEmpty {
            let cols = iconPalette.map { ImageUtils.colorFromARGB($0.intValue) }
            let cfg = NSImage.SymbolConfiguration(paletteColors: cols)
            image = image.withSymbolConfiguration(cfg) ?? image
          }
        case "multicolor":
          if #available(macOS 12.0, *) {
            let cfg = NSImage.SymbolConfiguration.preferringMulticolor()
            image = image.withSymbolConfiguration(cfg) ?? image
          }
        case "monochrome":
          if let c = iconColor { image = image.templateTinted(with: c) }
        default: break
        }
      } else if let c = iconColor {
        image = image.templateTinted(with: c)
      }
      return image
    }

    return nil
  }

  /// Convenience: resolve from a Flutter method-call args dict.
  private static func resolveImageFromArgs(_ args: [String: Any]) -> NSImage? {
    let xcassetName = args["buttonXcassetName"] as? String
    let assetPath = args["buttonAssetPath"] as? String
    let imageData = (args["buttonImageData"] as? FlutterStandardTypedData)?.data
    let imageFormat = args["buttonImageFormat"] as? String
    let customIconBytes = (args["buttonCustomIconBytes"] as? FlutterStandardTypedData)?.data
    let iconName = args["buttonIconName"] as? String
    let iconSize = (args["buttonIconSize"] as? NSNumber).map { CGFloat(truncating: $0) }
    let iconColor = (args["buttonIconColor"] as? NSNumber).map { ImageUtils.colorFromARGB($0.intValue) }
    let iconMode = args["buttonIconRenderingMode"] as? String
    let iconPalette = (args["buttonIconPaletteColors"] as? [NSNumber]) ?? []
    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    return resolveImage(
      xcassetName: xcassetName,
      assetPath: assetPath,
      imageData: imageData,
      imageFormat: imageFormat,
      customIconBytes: customIconBytes,
      iconName: iconName,
      iconSize: iconSize,
      iconColor: iconColor,
      iconMode: iconMode,
      iconPalette: iconPalette,
      iconScale: scale
    )
  }

  /// Apply icon size/color hints for raster images.
  private static func _applyIconStyling(image: NSImage, size: CGFloat?, color: NSColor?) -> NSImage {
    var out = image
    if let sz = size, image.size != NSSize(width: sz, height: sz) {
      let target = NSImage(size: NSSize(width: sz, height: sz))
      target.lockFocus()
      image.draw(in: NSRect(x: 0, y: 0, width: sz, height: sz),
                 from: NSRect(origin: .zero, size: image.size),
                 operation: .sourceOver,
                 fraction: 1.0)
      target.unlockFocus()
      out = target
    }
    if let col = color {
      out = out.templateTinted(with: col)
    }
    return out
  }
}

private extension NSImage {
  /// Returns a copy of the image tinted with the given color.
  /// Treats the source as a template even if `isTemplate` is false so callers
  /// can pass either bundle images or SF Symbols.
  func templateTinted(with color: NSColor) -> NSImage {
    let img = NSImage(size: size)
    img.lockFocus()
    let rect = NSRect(origin: .zero, size: size)
    color.set()
    rect.fill()
    draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
    img.unlockFocus()
    img.isTemplate = false
    return img
  }
}
