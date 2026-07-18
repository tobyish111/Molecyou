import Charts
import SwiftUI

@MainActor
@Observable
final class TodayViewModel {
    private let healthProvider: any HealthDataProviding
    private let contextEngine: any HealthContextEvaluating
    private let interests: Set<UserInterest>

    var snapshot = HealthSnapshot.empty(isDemo: true)
    var recommendations: [HealthContextRecommendation] = []
    var isLoading = true

    init(healthProvider: any HealthDataProviding, contextEngine: any HealthContextEvaluating, interests: Set<UserInterest>) {
        self.healthProvider = healthProvider
        self.contextEngine = contextEngine
        self.interests = interests
    }

    func load() async {
        isLoading = true
        snapshot = await healthProvider.snapshot()
        recommendations = contextEngine.evaluate(snapshot: snapshot, interests: interests)
        isLoading = false
    }
}

struct TodayView: View {
    let environment: AppEnvironment
    @State private var viewModel: TodayViewModel

    init(environment: AppEnvironment) {
        self.environment = environment
        _viewModel = State(initialValue: TodayViewModel(healthProvider: environment.healthProvider, contextEngine: environment.contextEngine, interests: Set(UserInterest.allCases)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                header
                if viewModel.snapshot.isDemo {
                    Label("Demonstration data", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.14), in: Capsule())
                }
                highlights
                systemsInFocus
                ActivitySummaryCard(snapshot: viewModel.snapshot)
                DisclaimerCard()
            }
            .padding(MYSpacing.md)
        }
        .navigationTitle("Today")
        .moleculeScreenBackground()
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(GreetingGenerator.greeting(name: "Toby"))
                .font(.largeTitle.bold())
                .minimumScaleFactor(0.8)
            Text("Here’s what’s happening in your body today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Today’s Highlights")
            NavigationLink(value: AppRoute.system("oxygen-transport")) {
                HighlightCard(title: "Cardiovascular", subtitle: "Your recent activity makes oxygen transport interesting to explore.", symbol: "heart.fill", gradient: MYGradient.oxygen)
            }
            .buttonStyle(.plain)
            HStack(spacing: MYSpacing.md) {
                NavigationLink(value: AppRoute.system("sleep-circadian")) {
                    HighlightCard(title: "Recovery", subtitle: "Sleep timing connects to circadian biology.", symbol: "moon.stars.fill", gradient: MYGradient.recovery, compact: true)
                }
                NavigationLink(value: AppRoute.system("muscle-contraction")) {
                    HighlightCard(title: "Activity", subtitle: "Movement starts with molecular motors.", symbol: "figure.run", gradient: MYGradient.activity, compact: true)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var systemsInFocus: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Systems in Focus", detail: "Based on recent context")
            ForEach(viewModel.recommendations) { recommendation in
                if let system = environment.knowledgeGraph.system(id: recommendation.systemID) {
                    NavigationLink(value: AppRoute.system(system.id)) {
                        SystemFocusRow(system: system, recommendation: recommendation)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct HighlightCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let gradient: LinearGradient
    var compact = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(compact ? .title : .largeTitle)
                    .foregroundStyle(.white)
                Text(title)
                    .font(compact ? .headline : .title3.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(3)
                Label("View insights", systemImage: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(MYSpacing.md)
        .frame(maxWidth: .infinity, minHeight: compact ? 150 : 176, alignment: .leading)
        .background(gradient, in: RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
        .overlay(alignment: .topTrailing) {
            MolecularLogo(size: compact ? 46 : 72)
                .opacity(0.45)
                .padding(12)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SystemFocusRow: View {
    let system: BiologicalSystem
    let recommendation: HealthContextRecommendation

    var body: some View {
        GlassCard {
            HStack(spacing: MYSpacing.md) {
                GradientIcon(symbol: system.icon, colors: system.accentColors.compactMap(Color.init(hex:)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(system.name)
                        .font(.headline)
                    Text(recommendation.reasons.first ?? system.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                RelevanceBadge(relevance: recommendation.relevance)
            }
        }
    }
}

struct ActivitySummaryCard: View {
    let snapshot: HealthSnapshot
    private let trend = [420, 260, 510, 330, 620, 270, 480]

    var body: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Activity Summary", detail: "This week")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                MetricTile(symbol: "figure.run", title: "Workouts", value: snapshot.workoutsThisWeek.map(String.init) ?? "No data")
                MetricTile(symbol: "flame", title: "Active Energy", value: UnitFormatter.energy(snapshot.activeEnergyThisWeek))
                MetricTile(symbol: "heart", title: "Resting HR", value: UnitFormatter.heartRate(snapshot.restingHeartRate))
                MetricTile(symbol: "moon", title: "Sleep Avg.", value: UnitFormatter.sleep(snapshot.averageSleepDuration))
            }
            Chart(Array(trend.enumerated()), id: \.offset) { item in
                BarMark(x: .value("Day", item.offset + 1), y: .value("Energy", item.element))
                    .foregroundStyle(Color.myAccent.gradient)
            }
            .frame(height: 150)
            .accessibilityLabel("Seven day sample activity trend chart")
        }
        .padding(MYSpacing.md)
        .background(Color.myPanel, in: RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
    }
}

struct MetricTile: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Color.myAccent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: MYRadius.md))
        .accessibilityElement(children: .combine)
    }
}

struct DisclaimerCard: View {
    var body: some View {
        Label(Disclaimer.text, systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(MYSpacing.md)
            .background(Color.myPanel, in: RoundedRectangle(cornerRadius: MYRadius.md))
    }
}

#Preview("Today") {
    NavigationStack { TodayView(environment: .preview) }
}
