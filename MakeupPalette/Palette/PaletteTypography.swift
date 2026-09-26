import SwiftUI

enum PaletteTypography {
  static var title: Font { .custom("HelveticaNeue-Medium", size: 26, relativeTo: .title) }
  static var section: Font { .custom("HelveticaNeue-Bold", size: 19, relativeTo: .headline) }
  static var label: Font { .custom("HelveticaNeue", size: 14, relativeTo: .subheadline) }
}
