import SwiftUI

/// Branded launch/splash screen shown while the app prepares its environment.
///
/// It mirrors the onboarding welcome styling (dark gradient, molecular logo,
/// wordmark, and tagline) so the cold-start hand-off from the native launch
/// screen — `LaunchScreen.storyboard`, which uses the same dark background —
/// flows seamlessly into the running app.
struct LaunchScreenView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            MYGradient.darkBackground
                .ignoresSafeArea()

            // Soft accent glow behind the logo for a little depth.
            RadialGradient(
                colors: [Color.myAccent.opacity(0.35), .clear],
                center: .center,
                startRadius: 8,
                endRadius: 280
            )
            .ignoresSafeArea()
            .opacity(appeared ? 1 : 0)

            VStack(spacing: MYSpacing.lg) {
                MolecularLogo(size: 96)
                    .scaleEffect(appeared ? 1 : 0.72)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: MYSpacing.sm) {
                    Text("Molecyou")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Understand your health from the molecular level.")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
            .padding(MYSpacing.xl)
        }
        .task {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Molecyou. Understand your health from the molecular level.")
    }
}

#Preview {
    LaunchScreenView()
}
