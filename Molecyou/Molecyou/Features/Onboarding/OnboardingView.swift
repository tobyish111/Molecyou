import SwiftUI

struct OnboardingView: View {
    let environment: AppEnvironment
    @Binding var hasCompletedOnboarding: Bool
    @AppStorage("demonstrationMode") private var demonstrationMode = true
    @State private var page = 0
    @State private var selectedInterests = Set(UserInterest.allCases.prefix(4))
    @State private var healthState: HealthAuthorizationState = .notRequested

    var body: some View {
        ZStack(alignment: .bottom) {
            currentPage
                .id(page)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Color.white : Color.white.opacity(0.28))
                        .frame(width: index == page ? 9 : 7, height: index == page ? 9 : 7)
                }
            }
            .padding(.bottom, 18)
            .accessibilityHidden(true)
        }
        .background(MYGradient.darkBackground.ignoresSafeArea())
        .foregroundStyle(.white)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: page)
    }

    @ViewBuilder
    private var currentPage: some View {
        switch page {
        case 0: welcome
        case 1: privacy
        case 2: interests
        case 3: permissions
        default: completion
        }
    }

    private var welcome: some View {
        OnboardingPage {
            MolecularLogo(size: 78)
            Text("Molecyou")
                .font(.largeTitle.bold())
            Text("Understand your health from the molecular level.")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("Explore the molecular systems related to your health, fitness, sleep, and daily activity.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
            FeatureRow(symbol: "heart.text.square", title: "Powered by HealthKit", body: "Uses read-only health and activity categories to suggest educational topics.")
            FeatureRow(symbol: "cube.transparent", title: "Explore in 3D", body: "Interactive reference protein structures from AlphaFold DB.")
            FeatureRow(symbol: "books.vertical", title: "Science you can understand", body: "Short modules explain physiology without medical claims.")
            Button("Continue") { page = 1 }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("Onboarding Welcome Continue")
                .controlSize(.large)
        }
    }

    private var privacy: some View {
        OnboardingPage {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.mint)
            Text("Health privacy first")
                .font(.title.bold())
            Text("HealthKit access is optional. Raw HealthKit measurements are processed on-device and are not uploaded. You can revoke access at any time, and the app remains usable in demonstration mode.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            Toggle("Use demonstration mode", isOn: $demonstrationMode)
                .toggleStyle(.switch)
                .padding()
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: MYRadius.lg))
            Text(Disclaimer.text)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
            Button("Continue") { page = 2 }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("Onboarding Privacy Continue")
        }
    }

    private var interests: some View {
        OnboardingPage {
            Text("Select interests")
                .font(.title.bold())
            Text("These guide educational recommendations. You can change them later.")
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(UserInterest.allCases) { interest in
                    Button {
                        if selectedInterests.contains(interest) { selectedInterests.remove(interest) } else { selectedInterests.insert(interest) }
                    } label: {
                        HStack {
                            Image(systemName: selectedInterests.contains(interest) ? "checkmark.circle.fill" : "circle")
                            Text(interest.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(selectedInterests.contains(interest) ? Color.myAccent.opacity(0.35) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: MYRadius.md))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(selectedInterests.contains(interest) ? "Double tap to remove this interest" : "Double tap to select this interest")
                }
            }
            Button("Continue") { page = 3 }
                .buttonStyle(.borderedProminent)
                .disabled(selectedInterests.isEmpty)
                .accessibilityIdentifier("Onboarding Interests Continue")
        }
    }

    private var permissions: some View {
        OnboardingPage {
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundStyle(.pink)
            Text("Connect HealthKit")
                .font(.title.bold())
            Text("Molecyou asks for read-only access to workouts, active energy, heart-rate summaries, sleep, respiratory rate, oxygen saturation, and VO2 max when available. These categories recommend educational topics only.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            VStack(alignment: .leading, spacing: 10) {
                Label("No write access is requested", systemImage: "pencil.slash")
                Label("No raw health samples are uploaded", systemImage: "icloud.slash")
                Label("Demo mode remains available", systemImage: "sparkles")
            }
            .font(.callout)
            .padding()
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: MYRadius.lg))
            Button(demonstrationMode ? "Continue in Demo Mode" : "Request Health Access") {
                if demonstrationMode {
                    page = 4
                } else {
                    Task {
                        healthState = await environment.requestHealthAuthorization()
                        page = 4
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("Onboarding Permission Continue")
            Button("Skip for now") { page = 4 }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var completion: some View {
        OnboardingPage {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.mint)
            Text("You’re ready")
                .font(.title.bold())
            Text("Selected interests")
                .font(.headline)
            Text(selectedInterests.map(\.rawValue).sorted().joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Text("You can update interests, privacy choices, cache, and demonstration mode from Profile.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
            Button("Enter Molecyou") {
                environment.analytics.track(AnalyticsEvent(name: "onboarding_completed", properties: ["demo": String(demonstrationMode)]))
                hasCompletedOnboarding = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("Enter Molecyou")
        }
    }
}

private struct OnboardingPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: MYSpacing.lg) { content }
                .padding(MYSpacing.xl)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let bodyText: String

    init(symbol: String, title: String, body: String) {
        self.symbol = symbol
        self.title = title
        self.bodyText = body
    }

    var body: some View {
        HStack(spacing: MYSpacing.md) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.cyan)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(bodyText).font(.subheadline).foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
        }
        .frame(maxWidth: 520)
    }
}

enum Disclaimer {
    static let text = "Molecyou provides educational information about human biology and reference protein structures. It does not diagnose, treat, cure, or prevent medical conditions and does not measure molecular activity inside your body. Contact a qualified healthcare professional regarding medical questions."
}

#Preview("Onboarding") {
    OnboardingView(environment: .preview, hasCompletedOnboarding: .constant(false))
}
