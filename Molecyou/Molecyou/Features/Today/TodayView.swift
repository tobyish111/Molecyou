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
                TodayDataStatusBadge(snapshot: viewModel.snapshot)
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
                HighlightCard(title: "Cardiovascular", subtitle: "Oxygen transport is an important system to explore in human physiology.", symbol: "heart.fill", gradient: MYGradient.oxygen)
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
                    .accessibilityIdentifier("SystemFocus \(system.id)")
                }
            }
        }
    }
}

struct TodayDataStatusBadge: View {
    let snapshot: HealthSnapshot

    private var hasAnyRealValue: Bool {
        snapshot.workoutsThisWeek != nil || snapshot.activeEnergyThisWeek != nil || snapshot.averageWorkoutHeartRate != nil || snapshot.restingHeartRate != nil || snapshot.averageSleepDuration != nil || snapshot.respiratoryRate != nil || snapshot.oxygenSaturation != nil || snapshot.vo2Max != nil
    }

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
            .accessibilityIdentifier(identifier)
    }

    private var title: String {
        if snapshot.isDemo { return "Demonstration data" }
        return hasAnyRealValue ? "HealthKit data linked" : "No HealthKit data linked"
    }

    private var symbol: String {
        if snapshot.isDemo { return "sparkles" }
        return hasAnyRealValue ? "heart.text.square" : "heart.slash"
    }

    private var color: Color {
        if snapshot.isDemo { return .blue }
        return hasAnyRealValue ? .green : .orange
    }

    private var identifier: String {
        if snapshot.isDemo { return "Today Demo Data" }
        return hasAnyRealValue ? "Today Linked Health Data" : "Today No Health Data"
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

    private var color: Color {
        switch symbol {
        case "figure.run": .mint
        case "figure.mixed.cardio": .blue
        case "flame": .orange
        case "heart": .pink
        case "moon": .purple
        case "lungs": .cyan
        default: .myAccent
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: MYRadius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if symbol == "figure.mixed.cardio" {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(value)
                            .font(.headline)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(height: 24)
                    .accessibilityLabel(value)
                } else {
                    Text(value)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 66, maxHeight: 66, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                Color(.tertiarySystemGroupedBackground)
                LinearGradient(colors: [color.opacity(0.14), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
            }
            .clipShape(RoundedRectangle(cornerRadius: MYRadius.md))
        }
        .overlay(RoundedRectangle(cornerRadius: MYRadius.md).stroke(color.opacity(0.12), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityIdentifier("Metric \(title)")
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
