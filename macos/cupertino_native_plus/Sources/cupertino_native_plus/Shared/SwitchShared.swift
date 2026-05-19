import SwiftUI

#if os(iOS)
public struct CupertinoSwitchView: View {
  @ObservedObject public var model: SwitchModel

  public init(model: SwitchModel) {
    self.model = model
  }

  public var body: some View {
    let base = Toggle("", isOn: $model.value)
      .labelsHidden()
      .disabled(!model.enabled)

    if #available(iOS 14.0, *) {
      if #available(iOS 15.0, *) {
        base
          .onChange(of: model.value) { newValue in
            model.onChange(newValue)
          }
          .tint(model.tintColor)
      } else {
        base
          .onChange(of: model.value) { newValue in
            model.onChange(newValue)
          }
          .accentColor(model.tintColor)
      }
    } else {
      if #available(iOS 15.0, *) {
        base
          .onReceive(model.$value) { newValue in
            model.onChange(newValue)
          }
          .tint(model.tintColor)
      } else {
        base
          .onReceive(model.$value) { newValue in
            model.onChange(newValue)
          }
          .accentColor(model.tintColor)
      }
    }
  }
}
#elseif os(macOS)
public struct CupertinoSwitchView: View {
  @ObservedObject public var model: SwitchModel

  public init(model: SwitchModel) {
    self.model = model
  }

  public var body: some View {
    let base = Toggle("", isOn: $model.value)
      .labelsHidden()
      .disabled(!model.enabled)
      .onChange(of: model.value) { newValue in
        model.onChange(newValue)
      }

    if #available(macOS 12.0, *) {
      base.tint(model.tintColor)
    } else {
      base.accentColor(model.tintColor)
    }
  }
}
#endif

public class SwitchModel: ObservableObject {
  @Published public var value: Bool
  @Published public var enabled: Bool
  @Published public var tintColor: Color = .accentColor
  public var onChange: (Bool) -> Void

  public init(value: Bool, enabled: Bool, onChange: @escaping (Bool) -> Void) {
    self.value = value
    self.enabled = enabled
    self.onChange = onChange
  }
}
