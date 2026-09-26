import SwiftUI

/// Subscription paywall shown when a locked premium swatch is tapped.
///
/// Reads live state from the `PremiumStore`: shows a spinner while a purchase
/// is in flight, surfaces failures, and dismisses only once the subscription
/// is actually active. Works the same over `MockPremiumStore` and RevenueCat.
struct PaywallView: View {
  var store: any PremiumStore

  @Environment(\.dismiss) private var dismiss

  private let accent = Color(red: 0.71, green: 0.32, blue: 0.43)

  private let perks = [
    "Every premium shade, unlocked",
    "Custom colors with the color wheel",
    "Brow shapes & full effects",
    "New shades added every month"
  ]

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 24) {
            VStack(spacing: 12) {
              ZStack {
                Circle()
                  .fill(accent.opacity(0.12))
                  .frame(width: 84, height: 84)
                Image(systemName: "sparkles")
                  .font(.system(size: 38, weight: .medium))
                  .foregroundStyle(accent)
              }
              .padding(.top, 8)

              Text("MakeUp Mirror Premium")
                .font(.custom("HelveticaNeue-Bold", size: 24))
                .multilineTextAlignment(.center)

              Text("Unlock every shade and the full try-on toolkit.")
                .font(.custom("HelveticaNeue", size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
              ForEach(perks, id: \.self) { perk in
                HStack(spacing: 12) {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(accent)
                  Text(perk)
                    .font(.custom("HelveticaNeue", size: 15))
                  Spacer(minLength: 0)
                }
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 18))
          }
          .padding(24)
        }

        VStack(spacing: 12) {
          if let error = store.lastPurchaseError {
            Text(error)
              .font(.custom("HelveticaNeue", size: 12))
              .foregroundStyle(.red)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }

          Button {
            store.subscribe()
          } label: {
            Group {
              if store.isPurchasing {
                ProgressView()
                  .tint(.white)
              } else {
                VStack(spacing: 2) {
                  Text("Subscribe")
                    .font(.custom("HelveticaNeue-Bold", size: 18))
                  Text("\(store.monthlyPriceText) / month")
                    .font(.custom("HelveticaNeue", size: 13))
                    .opacity(0.9)
                }
              }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accent, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
          }
          .disabled(store.isPurchasing)

          Button("Restore Purchases") {
            store.restore()
          }
          .font(.custom("HelveticaNeue", size: 14))
          .foregroundStyle(accent)
          .disabled(store.isPurchasing)

          Text("Cancel anytime. Billed monthly.")
            .font(.custom("HelveticaNeue", size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
      }
      .background(.white)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
          }
          .tint(.black)
        }
      }
    }
    .environment(\.colorScheme, .light)
    // Close only once the subscription is actually active.
    .onChange(of: store.isSubscribed) { _, subscribed in
      if subscribed { dismiss() }
    }
  }
}
