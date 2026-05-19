import AppKit

// MARK: - CNIcon platform resolution (macOS)

extension CNIcon {
  /// Returns `(platformImage, symbolName)`.
  /// Exactly one of the two values is non-nil (symbol → (nil, name), others → (image, nil)).
  public func resolve(
    width: CGFloat,
    height: CGFloat,
    scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
  ) -> (PlatformImage?, String?) {
    let size = CGSize(width: width, height: height)

    switch source {
    case .symbol(let name):
      return (nil, name)

    case .xcasset(let name):
      return (_cnLoadNamed(name), nil)

    case .asset(let path, let format):
      return (ImageUtils.loadFlutterAsset(path, size: size, format: format, scale: scale), nil)

    case .png(let d), .jpg(let d):
      return (ImageUtils.createImageFromData(d, format: source.formatString, size: size, scale: scale), nil)

    case .svg:
      // SVG not supported on macOS
      return (nil, nil)

    case .rawData(let bytes, let format):
      return (ImageUtils.createImageFromData(bytes, format: format, size: size, scale: scale), nil)
    }
  }
}
