import FlutterMacOS
import AppKit
import SwiftUI

// MARK: - Config

struct CNSearchBarConfig {
  let placeholder: String
  let expandable: Bool
  let initiallyExpanded: Bool
  let collapsedWidth: CGFloat
  let expandedHeight: CGFloat
  let tint: NSColor?
  let backgroundColor: NSColor?
  let textColor: NSColor?
  let placeholderColor: NSColor?
  let showCancelButton: Bool
  let cancelText: String
  let autofocus: Bool
  let searchIconName: String
  let clearIconName: String
  let isDark: Bool

  static func parse(from args: Any?) -> CNSearchBarConfig {
    var placeholder = "Search"
    var expandable = true
    var initiallyExpanded = false
    var collapsedWidth: CGFloat = 44
    var expandedHeight: CGFloat = 36
    var tint: NSColor? = nil
    var backgroundColor: NSColor? = nil
    var textColor: NSColor? = nil
    var placeholderColor: NSColor? = nil
    var showCancelButton = true
    var cancelText = "Cancel"
    var autofocus = false
    var searchIconName = "magnifyingglass"
    var clearIconName = "xmark.circle.fill"
    var isDark = false

    if let dict = args as? [String: Any] {
      if let v = dict["placeholder"] as? String { placeholder = v }
      if let v = dict["expandable"] as? Bool { expandable = v }
      if let v = dict["initiallyExpanded"] as? Bool { initiallyExpanded = v }
      if let v = dict["collapsedWidth"] as? NSNumber { collapsedWidth = CGFloat(truncating: v) }
      if let v = dict["expandedHeight"] as? NSNumber { expandedHeight = CGFloat(truncating: v) }
      if let v = dict["tint"] as? NSNumber { tint = ImageUtils.colorFromARGB(v.intValue) }
      if let v = dict["backgroundColor"] as? NSNumber { backgroundColor = ImageUtils.colorFromARGB(v.intValue) }
      if let v = dict["textColor"] as? NSNumber { textColor = ImageUtils.colorFromARGB(v.intValue) }
      if let v = dict["placeholderColor"] as? NSNumber { placeholderColor = ImageUtils.colorFromARGB(v.intValue) }
      if let v = dict["showCancelButton"] as? Bool { showCancelButton = v }
      if let v = dict["cancelText"] as? String { cancelText = v }
      if let v = dict["autofocus"] as? Bool { autofocus = v }
      if let v = dict["searchIconName"] as? String { searchIconName = v }
      if let v = dict["clearIconName"] as? String { clearIconName = v }
      if let v = dict["isDark"] as? Bool { isDark = v }
    }

    return CNSearchBarConfig(
      placeholder: placeholder,
      expandable: expandable,
      initiallyExpanded: initiallyExpanded,
      collapsedWidth: collapsedWidth,
      expandedHeight: expandedHeight,
      tint: tint,
      backgroundColor: backgroundColor,
      textColor: textColor,
      placeholderColor: placeholderColor,
      showCancelButton: showCancelButton,
      cancelText: cancelText,
      autofocus: autofocus,
      searchIconName: searchIconName,
      clearIconName: clearIconName,
      isDark: isDark
    )
  }
}

// MARK: - Platform View

class CupertinoSearchBarNSView: NSObject, NSSearchFieldDelegate {
  private let container: NSView
  private let channel: FlutterMethodChannel
  private var config: CNSearchBarConfig

  // Glass path (macOS 26+). Stored as Any? because the generic type is gated.
  private var hostingController: Any?

  // Fallback path (< macOS 26)
  private var searchField: NSSearchField?
  private var cancelButton: NSButton?

  private var suppressTextChangeEvent = false

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "\(ChannelConstants.viewIdCNSearchBar)_\(viewId)",
      binaryMessenger: messenger
    )
    self.container = NSView(frame: frame)
    self.container.wantsLayer = true
    self.container.layer?.backgroundColor = NSColor.clear.cgColor

    let cfg = CNSearchBarConfig.parse(from: args)
    self.config = cfg

    super.init()

    container.appearance = NSAppearance(named: cfg.isDark ? .darkAqua : .aqua)

    if #available(macOS 26.0, *) {
      installGlassHosting(cfg: cfg)
    } else {
      installFallback(cfg: cfg)
    }

    setupMethodChannel()

    if cfg.autofocus, cfg.initiallyExpanded || !cfg.expandable {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        self?.focus()
      }
    }
  }

  func view() -> NSView { container }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  // MARK: - Glass (macOS 26+)

  @available(macOS 26.0, *)
  private func installGlassHosting(cfg: CNSearchBarConfig) {
    let swiftUIView = CNSearchBarSwiftUIMac(
      config: cfg,
      onTextChanged: { [weak self] text in
        self?.channel.invokeMethod("textChanged", arguments: ["text": text])
      },
      onSubmitted: { [weak self] text in
        self?.channel.invokeMethod("submitted", arguments: ["text": text])
      },
      onExpandStateChanged: { [weak self] expanded in
        self?.channel.invokeMethod(expanded ? "expanded" : "collapsed", arguments: nil)
      },
      onCancelTapped: { [weak self] in
        self?.channel.invokeMethod("cancelTapped", arguments: nil)
      }
    )
    let hc = NSHostingController(rootView: swiftUIView)
    hc.view.wantsLayer = true
    hc.view.layer?.backgroundColor = NSColor.clear.cgColor
    hc.view.appearance = NSAppearance(named: cfg.isDark ? .darkAqua : .aqua)
    self.hostingController = hc

    hc.view.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(hc.view)
    NSLayoutConstraint.activate([
      hc.view.topAnchor.constraint(equalTo: container.topAnchor),
      hc.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      hc.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      hc.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
  }

  // MARK: - Fallback (< macOS 26)

  private func installFallback(cfg: CNSearchBarConfig) {
    let field = NSSearchField(frame: .zero)
    field.placeholderString = cfg.placeholder
    field.delegate = self
    field.target = self
    field.action = #selector(searchFieldAction(_:))
    field.translatesAutoresizingMaskIntoConstraints = false
    field.bezelStyle = .roundedBezel
    field.focusRingType = .default

    if let tc = cfg.textColor { field.textColor = tc }
    if let bg = cfg.backgroundColor {
      field.drawsBackground = true
      field.backgroundColor = bg
    }
    if let pc = cfg.placeholderColor {
      let attrs: [NSAttributedString.Key: Any] = [
        .foregroundColor: pc,
        .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
      ]
      field.placeholderAttributedString = NSAttributedString(string: cfg.placeholder, attributes: attrs)
    }

    container.addSubview(field)
    self.searchField = field

    var trailing = container.trailingAnchor
    if cfg.showCancelButton {
      let btn = NSButton(title: cfg.cancelText, target: self, action: #selector(cancelTapped))
      btn.bezelStyle = .inline
      btn.isBordered = false
      btn.translatesAutoresizingMaskIntoConstraints = false
      if let tint = cfg.tint {
        btn.attributedTitle = NSAttributedString(
          string: cfg.cancelText,
          attributes: [
            .foregroundColor: tint,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
          ]
        )
      }
      container.addSubview(btn)
      self.cancelButton = btn
      NSLayoutConstraint.activate([
        btn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        btn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
      ])
      trailing = btn.leadingAnchor
    }

    NSLayoutConstraint.activate([
      field.topAnchor.constraint(equalTo: container.topAnchor),
      field.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      field.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      field.trailingAnchor.constraint(equalTo: trailing, constant: cfg.showCancelButton ? -8 : 0),
    ])
  }

  // MARK: - Method channel

  private func setupMethodChannel() {
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }

      switch call.method {
      case "expand":
        result(nil)
      case "collapse":
        result(nil)
      case "clear":
        self.setText("")
        result(nil)
      case "setText":
        if let dict = call.arguments as? [String: Any], let text = dict["text"] as? String {
          self.setText(text)
        }
        result(nil)
      case "focus":
        self.focus()
        result(nil)
      case "unfocus":
        self.unfocus()
        result(nil)
      case ChannelConstants.methodUpdateConfig:
        let cfg = CNSearchBarConfig.parse(from: call.arguments)
        self.applyConfig(cfg)
        result(nil)
      case ChannelConstants.methodSetBrightness:
        if let dict = call.arguments as? [String: Any],
           let isDark = (dict["isDark"] as? NSNumber)?.boolValue {
          self.applyBrightness(isDark: isDark)
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func applyConfig(_ cfg: CNSearchBarConfig) {
    self.config = cfg
    if #available(macOS 26.0, *), let hc = hostingController as? NSHostingController<CNSearchBarSwiftUIMac> {
      hc.rootView = CNSearchBarSwiftUIMac(
        config: cfg,
        onTextChanged: { [weak self] text in
          self?.channel.invokeMethod("textChanged", arguments: ["text": text])
        },
        onSubmitted: { [weak self] text in
          self?.channel.invokeMethod("submitted", arguments: ["text": text])
        },
        onExpandStateChanged: { [weak self] expanded in
          self?.channel.invokeMethod(expanded ? "expanded" : "collapsed", arguments: nil)
        },
        onCancelTapped: { [weak self] in
          self?.channel.invokeMethod("cancelTapped", arguments: nil)
        }
      )
      hc.view.appearance = NSAppearance(named: cfg.isDark ? .darkAqua : .aqua)
    } else if let field = searchField {
      field.placeholderString = cfg.placeholder
      if let tc = cfg.textColor { field.textColor = tc }
      if let bg = cfg.backgroundColor {
        field.drawsBackground = true
        field.backgroundColor = bg
      }
      if let pc = cfg.placeholderColor {
        let attrs: [NSAttributedString.Key: Any] = [
          .foregroundColor: pc,
          .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
        ]
        field.placeholderAttributedString = NSAttributedString(string: cfg.placeholder, attributes: attrs)
      }
      if let btn = cancelButton {
        if let tint = cfg.tint {
          btn.attributedTitle = NSAttributedString(
            string: cfg.cancelText,
            attributes: [
              .foregroundColor: tint,
              .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
            ]
          )
        } else {
          btn.title = cfg.cancelText
        }
      }
    }
    applyBrightness(isDark: cfg.isDark)
  }

  private func applyBrightness(isDark: Bool) {
    let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    container.appearance = appearance
    if #available(macOS 26.0, *), let hc = hostingController as? NSHostingController<CNSearchBarSwiftUIMac> {
      hc.view.appearance = appearance
    }
    searchField?.appearance = appearance
    cancelButton?.appearance = appearance
  }

  private func setText(_ text: String) {
    suppressTextChangeEvent = true
    searchField?.stringValue = text
    suppressTextChangeEvent = false
  }

  private func focus() {
    if let field = searchField {
      container.window?.makeFirstResponder(field)
    }
  }

  private func unfocus() {
    if let win = container.window, win.firstResponder === searchField?.currentEditor() || win.firstResponder === searchField {
      win.makeFirstResponder(nil)
    }
  }

  // MARK: - NSSearchField actions / delegate

  @objc private func searchFieldAction(_ sender: NSSearchField) {
    channel.invokeMethod("submitted", arguments: ["text": sender.stringValue])
  }

  @objc private func cancelTapped() {
    setText("")
    unfocus()
    channel.invokeMethod("cancelTapped", arguments: nil)
  }

  func controlTextDidChange(_ notification: Notification) {
    guard !suppressTextChangeEvent else { return }
    guard let field = notification.object as? NSSearchField else { return }
    channel.invokeMethod("textChanged", arguments: ["text": field.stringValue])
  }
}

// MARK: - SwiftUI Glass View (macOS 26+)

@available(macOS 26.0, *)
struct CNSearchBarSwiftUIMac: View {
  let config: CNSearchBarConfig
  let onTextChanged: (String) -> Void
  let onSubmitted: (String) -> Void
  let onExpandStateChanged: (Bool) -> Void
  let onCancelTapped: () -> Void

  @State private var isExpanded: Bool
  @State private var searchText: String = ""
  @FocusState private var isFocused: Bool
  @Namespace private var animation

  init(
    config: CNSearchBarConfig,
    onTextChanged: @escaping (String) -> Void,
    onSubmitted: @escaping (String) -> Void,
    onExpandStateChanged: @escaping (Bool) -> Void,
    onCancelTapped: @escaping () -> Void
  ) {
    self.config = config
    self.onTextChanged = onTextChanged
    self.onSubmitted = onSubmitted
    self.onExpandStateChanged = onExpandStateChanged
    self.onCancelTapped = onCancelTapped
    self._isExpanded = State(initialValue: config.initiallyExpanded || !config.expandable)
  }

  private var tintColor: Color {
    config.tint.map { Color($0) } ?? .blue
  }
  private var textColor: Color {
    config.textColor.map { Color($0) } ?? .primary
  }
  private var placeholderTint: Color {
    config.placeholderColor.map { Color($0) } ?? .secondary
  }

  var body: some View {
    HStack(spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: config.searchIconName)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(tintColor)
          .matchedGeometryEffect(id: "searchIcon", in: animation)

        if isExpanded {
          TextField(config.placeholder, text: $searchText)
            .textFieldStyle(.plain)
            .foregroundColor(textColor)
            .focused($isFocused)
            .onSubmit { onSubmitted(searchText) }
            .onChange(of: searchText) { newValue in
              onTextChanged(newValue)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .leading)))

          if !searchText.isEmpty {
            Button(action: {
              searchText = ""
              onTextChanged("")
            }) {
              Image(systemName: config.clearIconName)
                .font(.system(size: 14))
                .foregroundColor(placeholderTint)
            }
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .scale))
          }
        }
      }
      .padding(.horizontal, 10)
      .frame(height: config.expandedHeight)
      .frame(maxWidth: isExpanded ? .infinity : config.collapsedWidth)
      .background(glassBackground)
      .clipShape(Capsule())
      .contentShape(Capsule())
      .onTapGesture {
        if !isExpanded && config.expandable {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isExpanded = true
            onExpandStateChanged(true)
          }
          if config.autofocus {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              isFocused = true
            }
          }
        }
      }

      if config.showCancelButton && isExpanded {
        Button(action: {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isExpanded = false
            searchText = ""
            isFocused = false
            onExpandStateChanged(false)
            onCancelTapped()
          }
        }) {
          Text(config.cancelText)
            .foregroundColor(tintColor)
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .trailing).combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
  }

  @ViewBuilder
  private var glassBackground: some View {
    if #available(macOS 26.0, *) {
      Color.clear.glassEffect(.regular, in: .capsule)
    } else if let bg = config.backgroundColor {
      Color(bg)
    } else {
      Color(NSColor.controlBackgroundColor)
    }
  }
}
