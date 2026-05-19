import SwiftUI

#if os(iOS)
public struct CupertinoSliderView: View {
  @ObservedObject public var model: SliderModel

  public init(model: SliderModel) {
    self.model = model
  }

  public var body: some View {
    let slider = Slider(value: $model.value, in: model.min...model.max)
      .disabled(!model.enabled)
      .accentColor(model.tintColor)

    if #available(iOS 14.0, *) {
      slider.onChange(of: model.value) { newValue in
        model.onChange(newValue)
      }
    } else {
      slider.onReceive(model.$value) { newValue in
        model.onChange(newValue)
      }
    }
  }
}
#elseif os(macOS)
public struct CupertinoSliderView: View {
  @ObservedObject public var model: SliderModel

  public init(model: SliderModel) {
    self.model = model
  }

  public var body: some View {
    Group {
      if let s = model.step, s > 0 {
        Slider(value: $model.value, in: model.min...model.max, step: s)
      } else {
        Slider(value: $model.value, in: model.min...model.max)
      }
    }
    .disabled(!model.enabled)
    .onChange(of: model.value) { newValue in
      model.onChange(newValue)
    }
    .accentColor(model.tintColor)
  }
}
#endif

public class SliderModel: ObservableObject {
  @Published public var value: Double
  @Published public var min: Double
  @Published public var max: Double
  @Published public var enabled: Bool
  @Published public var tintColor: Color = .accentColor
  /// Optional step for macOS; iOS ignores.
  @Published public var step: Double? = nil
  public var onChange: (Double) -> Void

  public init(
    value: Double,
    min: Double,
    max: Double,
    enabled: Bool,
    step: Double? = nil,
    onChange: @escaping (Double) -> Void
  ) {
    self.value = value
    self.min = min
    self.max = max
    self.enabled = enabled
    self.step = step
    self.onChange = onChange
  }
}
