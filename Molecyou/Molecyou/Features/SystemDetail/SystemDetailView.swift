import SwiftUI

struct SystemDetailView: View {
    let environment: AppEnvironment
    let system: BiologicalSystem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                hero
                infoSection(title: "Overview", text: system.overview)
                infoSection(title: "Why it matters", text: system.whyItMatters)
                NavigationLink(value: AppRoute.healthContext(system.id)) {
                    SearchRow(symbol: "heart.text.square", title: "Relevant HealthKit context", subtitle: "See why this topic may appear based on available categories.")
                }
                .buttonStyle(.plain)
                keyProcesses
                keyProteins
                relatedModules
                DisclaimerCard()
            }
            .padding(MYSpacing.md)
        }
        .navigationTitle(system.name)
        .navigationBarTitleDisplayMode(.inline)
        .moleculeScreenBackground()
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: system.accentColors.compactMap(Color.init(hex:)), startPoint: .topLeading, endPoint: .bottomTrailing)
            MolecularLogo(size: 140)
                .opacity(0.22)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding()
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: system.icon).font(.largeTitle)
                Text(system.name).font(.largeTitle.bold())
                Text(system.shortDescription).font(.headline).foregroundStyle(.white.opacity(0.82))
            }
            .foregroundStyle(.white)
            .padding(MYSpacing.lg)
        }
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: MYRadius.xl, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func infoSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: title)
            Text(text).font(.body).foregroundStyle(.secondary)
        }
    }

    private var keyProcesses: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Key Processes")
            ForEach(environment.knowledgeGraph.pathways.filter { $0.systemID == system.id }) { pathway in
                SearchRow(symbol: "point.3.connected.trianglepath.dotted", title: pathway.name, subtitle: pathway.summary)
            }
        }
    }

    private var keyProteins: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Key Proteins")
            ForEach(environment.knowledgeGraph.proteins(for: system)) { protein in
                NavigationLink(value: AppRoute.protein(protein.uniprotAccession)) {
                    ProteinMiniRow(protein: protein)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var relatedModules: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Related Modules")
            ForEach(environment.knowledgeGraph.modules(for: system)) { module in
                NavigationLink(value: AppRoute.functionModule(module.id)) {
                    SearchRow(symbol: "book.pages", title: module.title, subtitle: module.summary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ProteinMiniRow: View {
    let protein: Protein

    var body: some View {
        GlassCard {
            HStack(spacing: MYSpacing.md) {
                ProteinThumbnail(accession: protein.uniprotAccession)
                VStack(alignment: .leading, spacing: 4) {
                    Text(protein.name).font(.headline)
                    Text("\(protein.geneSymbol) · \(protein.uniprotAccession)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ProteinThumbnail: View {
    let accession: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous)
                .fill(MYGradient.molecule)
            MolecularLogo(size: 34)
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }
}

struct HealthContextView: View {
    let environment: AppEnvironment
    let system: BiologicalSystem
    @State private var snapshot = HealthSnapshot.empty(isDemo: true)
    @State private var recommendation: HealthContextRecommendation?

    var body: some View {
        List {
            Section("Why this topic appeared") {
                ForEach(recommendation?.reasons ?? ["This system is part of your selected educational interests."], id: \.self) { reason in
                    Label(reason, systemImage: "checkmark.circle")
                }
            }
            Section("Available categories") {
                MetricLine("Workouts this week", snapshot.workoutsThisWeek.map(String.init) ?? "No data")
                MetricLine("Active energy", UnitFormatter.energy(snapshot.activeEnergyThisWeek))
                MetricLine("Resting heart rate", UnitFormatter.heartRate(snapshot.restingHeartRate))
                MetricLine("Sleep duration", UnitFormatter.sleep(snapshot.averageSleepDuration))
                MetricLine("Oxygen saturation", UnitFormatter.percent(snapshot.oxygenSaturation))
            }
            Section("Educational boundary") {
                Text("This content is educational. The app is not measuring your oxygen-carrying proteins or diagnosing a health condition.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Health Context")
        .task {
            snapshot = await environment.healthProvider.snapshot()
            recommendation = environment.contextEngine.evaluate(snapshot: snapshot, interests: Set(UserInterest.allCases)).first { $0.systemID == system.id }
        }
    }
}

private struct MetricLine: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary) }
    }
}

struct FunctionExplanationView: View {
    let module: EducationModule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                Text(module.summary).font(.headline).foregroundStyle(.secondary)
                if module.steps.isEmpty {
                    ErrorStateView(title: "Lesson in brief", message: module.summary, actionTitle: nil, action: nil)
                        .frame(minHeight: 260)
                } else {
                    ForEach(Array(module.steps.enumerated()), id: \.element.id) { index, step in
                        GlassCard {
                            HStack(alignment: .top, spacing: MYSpacing.md) {
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.myAccent, in: Circle())
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(step.title, systemImage: step.symbol)
                                        .font(.headline)
                                    Text(step.body).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                DisclaimerCard()
            }
            .padding(MYSpacing.md)
        }
        .navigationTitle(module.title)
        .moleculeScreenBackground()
    }
}

#Preview("System Detail") {
    NavigationStack { SystemDetailView(environment: .preview, system: KnowledgeGraphStore.preview.systems[0]) }
}
