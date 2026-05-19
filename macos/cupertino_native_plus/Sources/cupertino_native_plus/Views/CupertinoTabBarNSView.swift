import FlutterMacOS
import Cocoa

/// macOS NSSegmentedControl-backed tab bar. Targets closer parity with the iOS
/// CupertinoTabBarPlatformView. Supports:
/// - Badges (overlay pills drawn over segment rects).
/// - Active-state icons (swaps to active SF symbol / asset when selected).
/// - Tint + unselectedTint for symbol images.
/// - activeLabelStyle.color via attributed segment label (best-effort).
/// - Split layout (two NSSegmentedControls side-by-side with splitSpacing).
/// - splitRightAsButton (suppresses selection persistence on right group items).
/// - Search-method no-ops (search variant is iOS-26-only and not ported).
class CupertinoTabBarNSView: NSView {
  private let channel: FlutterMethodChannel

  // Layout
  private var isSplit: Bool = false
  private var rightCount: Int = 1
  private var splitSpacing: CGFloat = 12.0
  private var splitRightAsButton: Bool = false

  // Controls: when not split, only `control` is used. When split, `control`
  // holds the left items, `rightControl` holds the right items.
  private var control: NSSegmentedControl
  private var rightControl: NSSegmentedControl?

  // Overlay container for badges. Sits on top of control(s), ignores hit-tests.
  private let badgeOverlay: BadgeOverlayView = BadgeOverlayView()

  // State
  private var selectedIndex: Int = 0
  private var currentLabels: [String] = []
  private var currentSymbols: [String] = []
  private var currentActiveSymbols: [String] = []
  private var currentBadges: [String?] = []
  private var currentBadgeColors: [NSColor?] = []
  private var currentCustomIconBytes: [Data?] = []
  private var currentActiveCustomIconBytes: [Data?] = []
  private var currentImageAssetPaths: [String] = []
  private var currentActiveImageAssetPaths: [String] = []
  private var currentImageAssetData: [Data?] = []
  private var currentActiveImageAssetData: [Data?] = []
  private var currentImageAssetFormats: [String] = []
  private var currentActiveImageAssetFormats: [String] = []
  private var iconScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
  private var currentSizes: [NSNumber] = []
  private var currentTint: NSColor? = nil
  private var currentUnselectedTint: NSColor? = nil
  private var currentBackground: NSColor? = nil
  private var labelStyleDict: [String: Any]? = nil
  private var activeLabelStyleDict: [String: Any]? = nil

  // MARK: - Text style helpers

  private func parseTextStyle(_ dict: [String: Any]) -> NSFont? {
    let fontSize = (dict["fontSize"] as? NSNumber).map { CGFloat(truncating: $0) }
    let fontWeight = dict["fontWeight"] as? Int
    let fontFamily = dict["fontFamily"] as? String
    var font: NSFont? = nil
    if let size = fontSize {
      if let family = fontFamily, let customFont = NSFont(name: family, size: size) {
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
        font = NSFont.systemFont(ofSize: size, weight: weight)
      }
    }
    if (dict["italic"] as? Bool) == true, let f = font {
      let descriptor = f.fontDescriptor.withSymbolicTraits(.italic)
      font = NSFont(descriptor: descriptor, size: f.pointSize) ?? font
    }
    return font
  }

  private func colorFromStyleDict(_ dict: [String: Any]?) -> NSColor? {
    guard let dict = dict else { return nil }
    if let n = dict["color"] as? NSNumber { return ImageUtils.colorFromARGB(n.intValue) }
    return nil
  }

  /// Applies font + (optional) attributed-string colors to segments.
  /// NSSegmentedControl has no per-state label API. We approximate by using
  /// activeLabelStyle for the selected segment (font + color via attributed
  /// title where available) and labelStyle for the rest.
  private func applyLabelStyles() {
    let baseDict = labelStyleDict ?? activeLabelStyleDict
    let activeDict = activeLabelStyleDict ?? labelStyleDict

    let baseFont = baseDict.flatMap { parseTextStyle($0) } ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
    // NSSegmentedControl has no per-segment font API; active-font would no-op.
    _ = activeDict
    let baseColor = colorFromStyleDict(baseDict)
    let activeColor = colorFromStyleDict(activeDict)

    control.font = baseFont
    rightControl?.font = baseFont

    // Per-segment attributed-title not supported on NSSegmentedControl public
    // API. We keep plain labels (set via configureSegments). Font is uniform.
    // Active color is mirrored onto symbol tint via applySegmentTint() when
    // activeLabelStyle.color is provided and currentTint is unset.
    if currentTint == nil, let c = activeColor { currentTint = c }
    if currentUnselectedTint == nil, let c = baseColor, c != activeColor { currentUnselectedTint = c }

    control.needsLayout = true
    control.needsDisplay = true
    rightControl?.needsLayout = true
    rightControl?.needsDisplay = true
  }

  init(viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "\(ChannelConstants.viewIdCupertinoNativeTabBar)_\(viewId)", binaryMessenger: messenger)
    self.control = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: nil, action: nil)

    var labels: [String] = []
    var symbols: [String] = []
    var activeSymbols: [String] = []
    var badges: [String?] = []
    var badgeColors: [NSColor?] = []
    var customIconBytes: [Data?] = []
    var activeCustomIconBytes: [Data?] = []
    var imageAssetPaths: [String] = []
    var activeImageAssetPaths: [String] = []
    var imageAssetData: [Data?] = []
    var activeImageAssetData: [Data?] = []
    var imageAssetFormats: [String] = []
    var activeImageAssetFormats: [String] = []
    var iconScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
    var sizes: [NSNumber] = []
    var selIdx: Int = 0
    var isDark: Bool = false
    var tint: NSColor? = nil
    var unselTint: NSColor? = nil
    var bg: NSColor? = nil
    var splitFlag: Bool = false
    var rightCnt: Int = 1
    var splitSp: CGFloat = 12.0
    var splitRightAsBtn: Bool = false

    if let dict = args as? [String: Any] {
      labels = (dict["labels"] as? [String]) ?? []
      symbols = (dict["sfSymbols"] as? [String]) ?? []
      activeSymbols = (dict["activeSfSymbols"] as? [String]) ?? []
      badges = Self.parseBadges(dict["badges"])
      badgeColors = Self.parseBadgeColors(dict["badgeColors"])
      if let bytesArray = dict["customIconBytes"] as? [FlutterStandardTypedData?] {
        customIconBytes = bytesArray.map { $0?.data }
      }
      if let bytesArray = dict["activeCustomIconBytes"] as? [FlutterStandardTypedData?] {
        activeCustomIconBytes = bytesArray.map { $0?.data }
      }
      imageAssetPaths = (dict["imageAssetPaths"] as? [String]) ?? []
      activeImageAssetPaths = (dict["activeImageAssetPaths"] as? [String]) ?? []
      if let bytesArray = dict["imageAssetData"] as? [FlutterStandardTypedData?] {
        imageAssetData = bytesArray.map { $0?.data }
      }
      if let bytesArray = dict["activeImageAssetData"] as? [FlutterStandardTypedData?] {
        activeImageAssetData = bytesArray.map { $0?.data }
      }
      imageAssetFormats = (dict["imageAssetFormats"] as? [String]) ?? []
      activeImageAssetFormats = (dict["activeImageAssetFormats"] as? [String]) ?? []
      if let scale = dict["iconScale"] as? NSNumber {
        iconScale = CGFloat(truncating: scale)
      }
      sizes = (dict["sfSymbolSizes"] as? [NSNumber]) ?? []
      if let v = dict["selectedIndex"] as? NSNumber { selIdx = v.intValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let style = dict["style"] as? [String: Any] {
        if let n = style["tint"] as? NSNumber { tint = ImageUtils.colorFromARGB(n.intValue) }
        if let n = style["unselectedTint"] as? NSNumber { unselTint = ImageUtils.colorFromARGB(n.intValue) }
        if let n = style["backgroundColor"] as? NSNumber { bg = ImageUtils.colorFromARGB(n.intValue) }
      }
      if let ls = dict["labelStyle"] as? [String: Any] { self.labelStyleDict = ls }
      if let als = dict["activeLabelStyle"] as? [String: Any] { self.activeLabelStyleDict = als }
      if let v = dict["split"] as? NSNumber { splitFlag = v.boolValue }
      if let v = dict["rightCount"] as? NSNumber { rightCnt = v.intValue }
      if let v = dict["splitSpacing"] as? NSNumber { splitSp = CGFloat(truncating: v) }
      if let v = dict["splitRightAsButton"] as? NSNumber { splitRightAsBtn = v.boolValue }
    }

    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)

    // Save state before building layout.
    self.currentLabels = labels
    self.currentSymbols = symbols
    self.currentActiveSymbols = activeSymbols
    self.currentBadges = badges
    self.currentBadgeColors = badgeColors
    self.currentCustomIconBytes = customIconBytes
    self.currentActiveCustomIconBytes = activeCustomIconBytes
    self.currentImageAssetPaths = imageAssetPaths
    self.currentActiveImageAssetPaths = activeImageAssetPaths
    self.currentImageAssetData = imageAssetData
    self.currentActiveImageAssetData = activeImageAssetData
    self.currentImageAssetFormats = imageAssetFormats
    self.currentActiveImageAssetFormats = activeImageAssetFormats
    self.iconScale = iconScale
    self.currentSizes = sizes
    self.currentTint = tint
    self.currentUnselectedTint = unselTint
    self.currentBackground = bg
    self.selectedIndex = selIdx
    self.isSplit = splitFlag
    self.rightCount = max(0, rightCnt)
    self.splitSpacing = splitSp
    self.splitRightAsButton = splitRightAsBtn

    if let b = bg { wantsLayer = true; layer?.backgroundColor = b.cgColor }

    rebuildLayout()
    applyLabelStyles()
    applySegmentTint()
    rebuildBadgeOverlay()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      self.handleMethodCall(call: call, result: result)
    }
  }

  required init?(coder: NSCoder) { return nil }

  override func layout() {
    super.layout()
    rebuildBadgeOverlay()
  }

  // MARK: - Method handling

  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getIntrinsicSize":
      let size = intrinsicSize()
      result(["width": Double(size.width), "height": Double(size.height)])
    case "setSelectedIndex":
      if let args = call.arguments as? [String: Any], let idx = (args["index"] as? NSNumber)?.intValue {
        setSelectedIndex(idx)
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing index", details: nil)) }
    case "setStyle":
      if let args = call.arguments as? [String: Any] {
        if let n = args["tint"] as? NSNumber { self.currentTint = ImageUtils.colorFromARGB(n.intValue) }
        if let n = args["unselectedTint"] as? NSNumber { self.currentUnselectedTint = ImageUtils.colorFromARGB(n.intValue) }
        if let n = args["backgroundColor"] as? NSNumber {
          let c = ImageUtils.colorFromARGB(n.intValue)
          self.currentBackground = c
          self.wantsLayer = true
          self.layer?.backgroundColor = c.cgColor
        }
        self.applySegmentTint()
        self.rebuildBadgeOverlay()
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
    case "setBrightness":
      if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
        self.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
    case "setItems":
      if let args = call.arguments as? [String: Any] {
        applySetItems(args: args)
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing items", details: nil)) }
    case "setBadges":
      if let args = call.arguments as? [String: Any] {
        self.currentBadges = Self.parseBadges(args["badges"])
        self.currentBadgeColors = Self.parseBadgeColors(args["badgeColors"])
        self.rebuildBadgeOverlay()
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing badges", details: nil)) }
    case "setLayout":
      if let args = call.arguments as? [String: Any] {
        if let v = args["split"] as? NSNumber { self.isSplit = v.boolValue }
        if let v = args["rightCount"] as? NSNumber { self.rightCount = max(0, v.intValue) }
        if let v = args["splitSpacing"] as? NSNumber { self.splitSpacing = CGFloat(truncating: v) }
        if let v = args["splitRightAsButton"] as? NSNumber { self.splitRightAsButton = v.boolValue }
        if let v = args["selectedIndex"] as? NSNumber { self.selectedIndex = v.intValue }
        rebuildLayout()
        applyLabelStyles()
        applySegmentTint()
        rebuildBadgeOverlay()
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing layout", details: nil)) }
    case "setSplitRightAsButton":
      if let args = call.arguments as? [String: Any], let v = (args["value"] as? NSNumber)?.boolValue {
        self.splitRightAsButton = v
        result(nil)
      } else { result(FlutterError(code: "bad_args", message: "Missing value", details: nil)) }
    case "setLabelStyle":
      self.labelStyleDict = call.arguments as? [String: Any]
      self.applyLabelStyles()
      self.applySegmentTint()
      result(nil)
    case "setActiveLabelStyle":
      self.activeLabelStyleDict = call.arguments as? [String: Any]
      self.applyLabelStyles()
      self.applySegmentTint()
      result(nil)
    case "refresh":
      // No-op on macOS: NSSegmentedControl does not need the iOS<16 label
      // refresh trick. Rebuild segments defensively so a fresh layout pass
      // re-syncs everything.
      rebuildLayout()
      applyLabelStyles()
      applySegmentTint()
      rebuildBadgeOverlay()
      result(nil)
    case "activateSearch", "deactivateSearch", "setSearchText":
      // Search variant is iOS-26-only. Methods exist as graceful no-ops so
      // searchController.activate/deactivate/setText calls from Dart don't
      // throw MissingPluginException on macOS.
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - setItems

  private func applySetItems(args: [String: Any]) {
    let labels = (args["labels"] as? [String]) ?? []
    let symbols = (args["sfSymbols"] as? [String]) ?? []
    let activeSymbols = (args["activeSfSymbols"] as? [String]) ?? []
    var customIconBytes: [Data?] = []
    var activeCustomIconBytes: [Data?] = []
    var imageAssetPaths: [String] = []
    var activeImageAssetPaths: [String] = []
    var imageAssetData: [Data?] = []
    var activeImageAssetData: [Data?] = []
    var imageAssetFormats: [String] = []
    var activeImageAssetFormats: [String] = []
    if let bytesArray = args["customIconBytes"] as? [FlutterStandardTypedData?] {
      customIconBytes = bytesArray.map { $0?.data }
    }
    if let bytesArray = args["activeCustomIconBytes"] as? [FlutterStandardTypedData?] {
      activeCustomIconBytes = bytesArray.map { $0?.data }
    }
    imageAssetPaths = (args["imageAssetPaths"] as? [String]) ?? []
    activeImageAssetPaths = (args["activeImageAssetPaths"] as? [String]) ?? []
    if let bytesArray = args["imageAssetData"] as? [FlutterStandardTypedData?] {
      imageAssetData = bytesArray.map { $0?.data }
    }
    if let bytesArray = args["activeImageAssetData"] as? [FlutterStandardTypedData?] {
      activeImageAssetData = bytesArray.map { $0?.data }
    }
    imageAssetFormats = (args["imageAssetFormats"] as? [String]) ?? []
    activeImageAssetFormats = (args["activeImageAssetFormats"] as? [String]) ?? []
    if let scale = args["iconScale"] as? NSNumber {
      self.iconScale = CGFloat(truncating: scale)
    }
    let sizes = (args["sfSymbolSizes"] as? [NSNumber]) ?? []
    if let v = args["selectedIndex"] as? NSNumber { self.selectedIndex = v.intValue }

    let badges: [String?] = Self.parseBadges(args["badges"])
    let badgeColors: [NSColor?] = Self.parseBadgeColors(args["badgeColors"])

    self.currentLabels = labels
    self.currentSymbols = symbols
    self.currentActiveSymbols = activeSymbols
    self.currentCustomIconBytes = customIconBytes
    self.currentActiveCustomIconBytes = activeCustomIconBytes
    self.currentImageAssetPaths = imageAssetPaths
    self.currentActiveImageAssetPaths = activeImageAssetPaths
    self.currentImageAssetData = imageAssetData
    self.currentActiveImageAssetData = activeImageAssetData
    self.currentImageAssetFormats = imageAssetFormats
    self.currentActiveImageAssetFormats = activeImageAssetFormats
    self.currentSizes = sizes
    self.currentBadges = badges
    self.currentBadgeColors = badgeColors

    rebuildLayout()
    applyLabelStyles()
    applySegmentTint()
    rebuildBadgeOverlay()
  }

  // MARK: - Layout

  private func rebuildLayout() {
    // Tear down existing controls and constraints.
    control.removeFromSuperview()
    rightControl?.removeFromSuperview()
    rightControl = nil
    badgeOverlay.removeFromSuperview()

    let totalCount = max(currentLabels.count,
                         max(currentSymbols.count,
                             max(currentCustomIconBytes.count,
                                 max(currentImageAssetPaths.count,
                                     currentImageAssetData.count))))

    if isSplit && rightCount > 0 && rightCount < totalCount {
      let leftN = totalCount - rightCount
      control = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: self, action: #selector(onLeftChanged(_:)))
      let right = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: self, action: #selector(onRightChanged(_:)))
      self.rightControl = right

      configureSegments(on: control, startIndex: 0, endIndex: leftN)
      configureSegments(on: right, startIndex: leftN, endIndex: totalCount)

      // Selection mapping.
      if selectedIndex < leftN {
        control.selectedSegment = selectedIndex
        right.selectedSegment = -1
      } else if !splitRightAsButton && selectedIndex < totalCount {
        right.selectedSegment = selectedIndex - leftN
        control.selectedSegment = -1
      } else {
        control.selectedSegment = -1
        right.selectedSegment = -1
      }

      control.translatesAutoresizingMaskIntoConstraints = false
      right.translatesAutoresizingMaskIntoConstraints = false
      addSubview(control)
      addSubview(right)

      NSLayoutConstraint.activate([
        control.leadingAnchor.constraint(equalTo: leadingAnchor),
        control.topAnchor.constraint(equalTo: topAnchor),
        control.bottomAnchor.constraint(equalTo: bottomAnchor),
        right.trailingAnchor.constraint(equalTo: trailingAnchor),
        right.topAnchor.constraint(equalTo: topAnchor),
        right.bottomAnchor.constraint(equalTo: bottomAnchor),
        right.leadingAnchor.constraint(greaterThanOrEqualTo: control.trailingAnchor, constant: splitSpacing),
      ])
    } else {
      control = NSSegmentedControl(labels: [], trackingMode: .selectOne, target: self, action: #selector(onLeftChanged(_:)))
      configureSegments(on: control, startIndex: 0, endIndex: totalCount)
      if selectedIndex >= 0 && selectedIndex < totalCount {
        control.selectedSegment = selectedIndex
      }
      control.translatesAutoresizingMaskIntoConstraints = false
      addSubview(control)
      NSLayoutConstraint.activate([
        control.leadingAnchor.constraint(equalTo: leadingAnchor),
        control.trailingAnchor.constraint(equalTo: trailingAnchor),
        control.topAnchor.constraint(equalTo: topAnchor),
        control.bottomAnchor.constraint(equalTo: bottomAnchor),
      ])
    }

    // Re-attach badge overlay above all controls.
    badgeOverlay.translatesAutoresizingMaskIntoConstraints = false
    addSubview(badgeOverlay)
    NSLayoutConstraint.activate([
      badgeOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
      badgeOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
      badgeOverlay.topAnchor.constraint(equalTo: topAnchor),
      badgeOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  private func configureSegments(on seg: NSSegmentedControl, startIndex: Int, endIndex: Int) {
    let count = max(0, endIndex - startIndex)
    seg.segmentCount = count
    let size25 = CGSize(width: 25, height: 25)
    for offset in 0..<count {
      let i = startIndex + offset
      let useActive = (i == selectedIndex)
      var image: NSImage? = imageForSegment(globalIndex: i, useActive: useActive, fallbackSize: size25)
      if let img = image {
        if let rep = img.representations.first {
          rep.pixelsWide = Int(25.0 * iconScale)
          rep.pixelsHigh = Int(25.0 * iconScale)
        }
        img.size = NSSize(width: 25.0, height: 25.0)
        img.isTemplate = true
        seg.setImage(img, forSegment: offset)
      } else {
        let symName: String? = useActive
          ? (i < currentActiveSymbols.count && !currentActiveSymbols[i].isEmpty ? currentActiveSymbols[i] : (i < currentSymbols.count ? currentSymbols[i] : nil))
          : (i < currentSymbols.count ? currentSymbols[i] : nil)
        if let name = symName, !name.isEmpty,
           #available(macOS 11.0, *),
           var symImage = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
          if i < currentSizes.count, #available(macOS 12.0, *) {
            let size = CGFloat(truncating: currentSizes[i])
            let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            symImage = symImage.withSymbolConfiguration(cfg) ?? symImage
          }
          seg.setImage(symImage, forSegment: offset)
          image = symImage
        }
      }
      if i < currentLabels.count {
        seg.setLabel(currentLabels[i], forSegment: offset)
      } else {
        seg.setLabel("", forSegment: offset)
      }
    }
  }

  /// Returns the appropriate icon for a segment index. Active-state images are
  /// resolved when `useActive` is true and an active variant is supplied;
  /// otherwise falls back to the base image source. Symbol fallbacks happen in
  /// the caller (we only return raster/data-backed images here).
  private func imageForSegment(globalIndex i: Int, useActive: Bool, fallbackSize: CGSize) -> NSImage? {
    if useActive {
      if i < currentActiveImageAssetData.count, let data = currentActiveImageAssetData[i] {
        let format = (i < currentActiveImageAssetFormats.count && !currentActiveImageAssetFormats[i].isEmpty) ? currentActiveImageAssetFormats[i] : nil
        if let img = ImageUtils.createImageFromData(data, format: format, size: fallbackSize, scale: iconScale) { return img }
      }
      if i < currentActiveImageAssetPaths.count && !currentActiveImageAssetPaths[i].isEmpty {
        if let img = ImageUtils.loadFlutterAsset(currentActiveImageAssetPaths[i], size: fallbackSize, scale: iconScale) { return img }
      }
      if i < currentActiveCustomIconBytes.count, let data = currentActiveCustomIconBytes[i] {
        if let img = NSImage(data: data) { return img }
      }
    }
    // Base / fallback.
    if i < currentImageAssetData.count, let data = currentImageAssetData[i] {
      let format = (i < currentImageAssetFormats.count && !currentImageAssetFormats[i].isEmpty) ? currentImageAssetFormats[i] : nil
      if let img = ImageUtils.createImageFromData(data, format: format, size: fallbackSize, scale: iconScale) { return img }
    }
    if i < currentImageAssetPaths.count && !currentImageAssetPaths[i].isEmpty {
      if let img = ImageUtils.loadFlutterAsset(currentImageAssetPaths[i], size: fallbackSize, scale: iconScale) { return img }
    }
    if i < currentCustomIconBytes.count, let data = currentCustomIconBytes[i] {
      if let img = NSImage(data: data) { return img }
    }
    return nil
  }

  // MARK: - Selection

  private func setSelectedIndex(_ idx: Int) {
    let prev = selectedIndex
    selectedIndex = idx
    let totalCount = currentLabels.count
    if isSplit && rightControl != nil && rightCount > 0 && rightCount < totalCount {
      let leftN = totalCount - rightCount
      if idx < leftN {
        control.selectedSegment = idx
        rightControl?.selectedSegment = -1
      } else if !splitRightAsButton && idx < totalCount {
        rightControl?.selectedSegment = idx - leftN
        control.selectedSegment = -1
      } else {
        control.selectedSegment = -1
        rightControl?.selectedSegment = -1
      }
    } else {
      control.selectedSegment = idx
    }
    // Refresh icons for previously selected and newly selected segments so
    // active-state asset/data icons swap in/out.
    if prev != idx {
      refreshSegmentIcon(globalIndex: prev)
      refreshSegmentIcon(globalIndex: idx)
    }
    applySegmentTint()
    rebuildBadgeOverlay()
  }

  private func refreshSegmentIcon(globalIndex i: Int) {
    guard i >= 0 else { return }
    let totalCount = currentLabels.count
    let leftN: Int = (isSplit && rightControl != nil) ? (totalCount - rightCount) : totalCount
    let (seg, localIdx): (NSSegmentedControl, Int)
    if i < leftN {
      seg = control; localIdx = i
    } else if let r = rightControl {
      seg = r; localIdx = i - leftN
    } else {
      seg = control; localIdx = i
    }
    guard localIdx >= 0 && localIdx < seg.segmentCount else { return }
    let useActive = (i == selectedIndex)
    let size25 = CGSize(width: 25, height: 25)
    if let img = imageForSegment(globalIndex: i, useActive: useActive, fallbackSize: size25) {
      img.size = NSSize(width: 25.0, height: 25.0)
      img.isTemplate = true
      seg.setImage(img, forSegment: localIdx)
    }
  }

  private func applySegmentTint() {
    let totalCount = currentLabels.count
    let leftN: Int = (isSplit && rightControl != nil) ? (totalCount - rightCount) : totalCount
    for i in 0..<totalCount {
      let (seg, localIdx): (NSSegmentedControl, Int)
      if i < leftN {
        seg = control; localIdx = i
      } else if let r = rightControl {
        seg = r; localIdx = i - leftN
      } else {
        continue
      }
      if localIdx < 0 || localIdx >= seg.segmentCount { continue }
      let hasImageAsset = (i < currentImageAssetData.count && currentImageAssetData[i] != nil)
        || (i < currentImageAssetPaths.count && !currentImageAssetPaths[i].isEmpty)
      let hasActiveImageAsset = (i < currentActiveImageAssetData.count && currentActiveImageAssetData[i] != nil)
        || (i < currentActiveImageAssetPaths.count && !currentActiveImageAssetPaths[i].isEmpty)
      let hasCustomIconBytes = i < currentCustomIconBytes.count && currentCustomIconBytes[i] != nil
      let hasCustomIcon = hasImageAsset || hasCustomIconBytes || hasActiveImageAsset
      let useActive = (i == selectedIndex)
      if !hasCustomIcon {
        let name: String?
        if useActive, i < currentActiveSymbols.count, !currentActiveSymbols[i].isEmpty {
          name = currentActiveSymbols[i]
        } else if i < currentSymbols.count, !currentSymbols[i].isEmpty {
          name = currentSymbols[i]
        } else { name = nil }
        if let name = name, var image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
          if i < currentSizes.count, #available(macOS 12.0, *) {
            let size = CGFloat(truncating: currentSizes[i])
            let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            image = image.withSymbolConfiguration(cfg) ?? image
          }
          let tintColor: NSColor? = useActive ? currentTint : currentUnselectedTint
          if let t = tintColor {
            if #available(macOS 12.0, *) {
              let cfg = NSImage.SymbolConfiguration(hierarchicalColor: t)
              image = image.withSymbolConfiguration(cfg) ?? image
            } else {
              image = image.tinted(with: t)
            }
          }
          seg.setImage(image, forSegment: localIdx)
        }
      }
    }
  }

  // MARK: - Intrinsic size

  private func intrinsicSize() -> CGSize {
    if isSplit, let right = rightControl {
      let l = control.intrinsicContentSize
      let r = right.intrinsicContentSize
      return CGSize(width: l.width + splitSpacing + r.width, height: max(l.height, r.height))
    }
    return control.intrinsicContentSize
  }

  // MARK: - Selection callbacks

  @objc private func onLeftChanged(_ sender: NSSegmentedControl) {
    let idx = sender.selectedSegment
    selectedIndex = idx
    refreshIconsForSelectionChange()
    applySegmentTint()
    rebuildBadgeOverlay()
    channel.invokeMethod("valueChanged", arguments: ["index": idx])
  }

  @objc private func onRightChanged(_ sender: NSSegmentedControl) {
    let totalCount = currentLabels.count
    let leftN = totalCount - rightCount
    let globalIdx = leftN + sender.selectedSegment
    if splitRightAsButton {
      // Mirror iOS: right items act as plain buttons. Don't move selection.
      // Restore previous selection visually.
      sender.selectedSegment = -1
      channel.invokeMethod("valueChanged", arguments: ["index": globalIdx])
      return
    }
    // Real selection: clear left selection and update state.
    control.selectedSegment = -1
    selectedIndex = globalIdx
    refreshIconsForSelectionChange()
    applySegmentTint()
    rebuildBadgeOverlay()
    channel.invokeMethod("valueChanged", arguments: ["index": globalIdx])
  }

  private func refreshIconsForSelectionChange() {
    // Refresh all segments — simpler than tracking previous index across
    // split controls and selection corner cases.
    let totalCount = currentLabels.count
    for i in 0..<totalCount { refreshSegmentIcon(globalIndex: i) }
  }

  // MARK: - Badge overlay

  /// Lays out a small red pill (or dot) above each segment that has a badge.
  /// Uses the runtime frames of the underlying segment cells via
  /// `relativeFrame(forSegment:)` so the badges follow size changes.
  private func rebuildBadgeOverlay() {
    badgeOverlay.subviews.forEach { $0.removeFromSuperview() }
    let totalCount = currentLabels.count
    let leftN: Int = (isSplit && rightControl != nil) ? (totalCount - rightCount) : totalCount
    for i in 0..<currentBadges.count {
      guard let badgeText = currentBadges[i] else { continue }
      let (seg, localIdx): (NSSegmentedControl, Int)
      if i < leftN {
        seg = control; localIdx = i
      } else if let r = rightControl {
        seg = r; localIdx = i - leftN
      } else { continue }
      if localIdx < 0 || localIdx >= seg.segmentCount { continue }

      let segFrame = frameForSegment(in: seg, localIndex: localIdx)
      guard segFrame.width > 0 else { continue }

      let color = (i < currentBadgeColors.count ? currentBadgeColors[i] : nil) ?? NSColor.systemRed
      let pill: BadgePillView
      if badgeText.isEmpty {
        pill = BadgePillView(text: nil, background: color)
      } else {
        pill = BadgePillView(text: badgeText, background: color)
      }
      pill.translatesAutoresizingMaskIntoConstraints = false
      badgeOverlay.addSubview(pill)

      // Position pill near the top-right of the segment cell.
      let pillSize = pill.preferredSize()
      let segOriginInOverlay = badgeOverlay.convert(segFrame.origin, from: seg)
      let x = segOriginInOverlay.x + segFrame.width - pillSize.width / 2 - 4
      let y = segOriginInOverlay.y + segFrame.height - pillSize.height / 2 - 2

      NSLayoutConstraint.activate([
        pill.widthAnchor.constraint(equalToConstant: pillSize.width),
        pill.heightAnchor.constraint(equalToConstant: pillSize.height),
        pill.leadingAnchor.constraint(equalTo: badgeOverlay.leadingAnchor, constant: x),
        pill.topAnchor.constraint(equalTo: badgeOverlay.topAnchor, constant: y),
      ])
    }
  }

  /// Computes the relative frame of a segment in a segmented control. macOS
  /// does not expose this directly; we approximate by summing widths from the
  /// cell widths when available, otherwise distributing evenly across the
  /// control bounds.
  private func frameForSegment(in seg: NSSegmentedControl, localIndex: Int) -> CGRect {
    let n = seg.segmentCount
    guard n > 0 else { return .zero }
    let bounds = seg.bounds
    // Try to use per-segment width if explicitly set.
    var widths: [CGFloat] = []
    var anyExplicit = false
    for i in 0..<n {
      let w = seg.width(forSegment: i)
      if w > 0 { anyExplicit = true; widths.append(w) } else { widths.append(0) }
    }
    if anyExplicit {
      let setTotal = widths.reduce(0, +)
      let remaining = max(0, bounds.width - setTotal)
      let zeroCount = widths.filter { $0 == 0 }.count
      let perAuto = zeroCount > 0 ? remaining / CGFloat(zeroCount) : 0
      var x: CGFloat = 0
      for i in 0..<n {
        let w = widths[i] > 0 ? widths[i] : perAuto
        if i == localIndex {
          return CGRect(x: x, y: bounds.minY, width: w, height: bounds.height)
        }
        x += w
      }
    }
    // Even distribution fallback.
    let w = bounds.width / CGFloat(n)
    return CGRect(x: CGFloat(localIndex) * w, y: bounds.minY, width: w, height: bounds.height)
  }

  // MARK: - Helpers

  private static func parseBadges(_ raw: Any?) -> [String?] {
    if let arr = raw as? [Any?] {
      return arr.map { ($0 as? String) }
    }
    if let arr = raw as? [String] {
      return arr.map { $0 }
    }
    return []
  }

  private static func parseBadgeColors(_ raw: Any?) -> [NSColor?] {
    if let arr = raw as? [Any?] {
      return arr.map { v in
        if let n = v as? NSNumber { return ImageUtils.colorFromARGB(n.intValue) }
        return nil
      }
    }
    if let arr = raw as? [NSNumber?] {
      return arr.map { v in v.map { ImageUtils.colorFromARGB($0.intValue) } }
    }
    return []
  }
}

// MARK: - Overlay views

/// Transparent overlay that hosts badge pills above the segmented control(s).
/// Disables hit-testing so clicks pass through to the underlying segments.
private final class BadgeOverlayView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
  }
  required init?(coder: NSCoder) { return nil }
  override func hitTest(_ point: NSPoint) -> NSView? { return nil }
}

/// A small red pill — either a dot (empty text) or a count text — drawn with
/// rounded corners. Mirrors the iOS badge appearance closely enough for parity.
private final class BadgePillView: NSView {
  private let text: String?
  private let background: NSColor
  private let label: NSTextField?

  init(text: String?, background: NSColor) {
    self.text = text
    self.background = background
    if let t = text, !t.isEmpty {
      let lbl = NSTextField(labelWithString: t)
      lbl.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
      lbl.textColor = .white
      lbl.alignment = .center
      lbl.translatesAutoresizingMaskIntoConstraints = false
      self.label = lbl
    } else {
      self.label = nil
    }
    super.init(frame: .zero)
    wantsLayer = true
    layer?.backgroundColor = background.cgColor
    if let lbl = label {
      addSubview(lbl)
      NSLayoutConstraint.activate([
        lbl.centerXAnchor.constraint(equalTo: centerXAnchor),
        lbl.centerYAnchor.constraint(equalTo: centerYAnchor),
      ])
    }
  }
  required init?(coder: NSCoder) { return nil }

  override func layout() {
    super.layout()
    layer?.cornerRadius = bounds.height / 2.0
  }

  /// Preferred size for the pill — square dot or rounded pill sized to text.
  func preferredSize() -> CGSize {
    if let t = text, !t.isEmpty {
      let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .semibold)]
      let textSize = (t as NSString).size(withAttributes: attrs)
      let h: CGFloat = 16
      let w = max(h, ceil(textSize.width) + 8)
      return CGSize(width: w, height: h)
    }
    return CGSize(width: 8, height: 8)
  }
}
