import SwiftUI

extension Color {
  init(makeupColor: MakeupColor) {
    self.init(
      red: Double(makeupColor.red),
      green: Double(makeupColor.green),
      blue: Double(makeupColor.blue)
    )
  }
}
