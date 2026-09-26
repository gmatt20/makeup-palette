struct MakeupColor: Equatable {
  var red: Float
  var green: Float
  var blue: Float

  init(red: Float, green: Float, blue: Float) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  init(rgb: UInt32) {
    red = Float((rgb >> 16) & 0xFF) / 255
    green = Float((rgb >> 8) & 0xFF) / 255
    blue = Float(rgb & 0xFF) / 255
  }
}
