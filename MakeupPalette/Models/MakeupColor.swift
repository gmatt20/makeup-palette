import Foundation

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

  /// Builds a color from hue/saturation/brightness (each 0...1), for the
  /// circular color picker.
  init(hue: Float, saturation: Float, brightness: Float) {
    let s = min(max(saturation, 0), 1)
    let v = min(max(brightness, 0), 1)
    let h6 = (hue - floor(hue)) * 6
    let sector = Int(h6) % 6
    let f = h6 - Float(Int(h6))
    let p = v * (1 - s)
    let q = v * (1 - s * f)
    let t = v * (1 - s * (1 - f))
    switch sector {
    case 0: self.init(red: v, green: t, blue: p)
    case 1: self.init(red: q, green: v, blue: p)
    case 2: self.init(red: p, green: v, blue: t)
    case 3: self.init(red: p, green: q, blue: v)
    case 4: self.init(red: t, green: p, blue: v)
    default: self.init(red: v, green: p, blue: q)
    }
  }

  /// The color decomposed into hue/saturation/brightness (each 0...1).
  var hsb: (hue: Float, saturation: Float, brightness: Float) {
    let maxV = max(red, green, blue)
    let minV = min(red, green, blue)
    let delta = maxV - minV
    var hue: Float = 0
    if delta > 0 {
      if maxV == red {
        hue = (green - blue) / delta
      } else if maxV == green {
        hue = (blue - red) / delta + 2
      } else {
        hue = (red - green) / delta + 4
      }
      hue /= 6
      if hue < 0 { hue += 1 }
    }
    let saturation = maxV == 0 ? 0 : delta / maxV
    return (hue, saturation, maxV)
  }
}
