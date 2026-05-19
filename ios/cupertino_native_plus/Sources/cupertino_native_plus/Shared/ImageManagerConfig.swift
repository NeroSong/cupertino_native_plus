import Foundation

/// Shared cache configuration for ImageManager. Used by both iOS and macOS.
public enum ImageManagerConfig {
  public static let cacheName = "com.cupertino_native_plus.ImageManager"
  public static let countLimit = 100
  public static let totalCostLimit = 50 * 1024 * 1024
}
