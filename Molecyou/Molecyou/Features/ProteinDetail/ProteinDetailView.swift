import SwiftUI

struct ProteinDetailView: View {
    let environment: AppEnvironment
    let protein: Protein
    @State private var prediction: AlphaFoldPrediction?
    @State private var errorMessage: String?
    @State private var healthSnapshot = HealthSnapshot.empty(isDemo: true)
    @State private var healthRecommendations: [HealthContextRecommendation] = []

    private var matchingHealthRecommendations: [HealthContextRecommendation] {
        healthRecommendations.filter { protein.systems.contains($0.systemID) }
    }

    private var proteinPalette: [Color] {
        ThumbnailPalette.colors(for: protein.uniprotAccession)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                header
                structureSummary
                keyFacts
                relatedSystems
                relatedModules
                healthContext
                sources
            }
            .padding(MYSpacing.md)
        }
        .navigationTitle(protein.geneSymbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                environment.libraryRepository.toggleProteinSaved(protein.uniprotAccession)
                environment.analytics.track(AnalyticsEvent(name: "protein_saved", properties: ["accession": protein.uniprotAccession]))
            } label: {
                Image(systemName: environment.libraryRepository.isProteinSaved(protein.uniprotAccession) ? "bookmark.fill" : "bookmark")
            }
            .accessibilityLabel(environment.libraryRepository.isProteinSaved(protein.uniprotAccession) ? "Unsave protein" : "Save protein")
            .accessibilityIdentifier("Save Protein")
        }
        .moleculeScreenBackground()
        .task {
            environment.libraryRepository.addRecent(itemID: protein.uniprotAccession, itemType: "protein")
            await loadPrediction()
            await loadHealthContext()
        }
    }

    private var header: some View {
        GlassCard {
            HStack(alignment: .top, spacing: MYSpacing.md) {
                ProteinThumbnail(accession: protein.uniprotAccession)
                VStack(alignment: .leading, spacing: 8) {
                    Text(protein.name)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(protein.geneSymbol) · \(protein.uniprotAccession)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.myAccent)
                    Text(protein.organism)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        tag(protein.proteinType.capitalized, symbol: "circle.hexagongrid")
                        tag(protein.cellularLocation, symbol: "location")
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .background {
            LinearGradient(colors: [proteinPalette.first?.opacity(0.16) ?? Color.myAccent.opacity(0.16), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LinearGradient(colors: proteinPalette, startPoint: .top, endPoint: .bottom))
                .frame(width: 4)
                .padding(.vertical, 14)
        }
    }

    private var structureSummary: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: MYSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Label {
                        Text("AlphaFold DB")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "cube.transparent")
                            .foregroundStyle(.cyan)
                    }
                    Spacer()
                    Label(prediction == nil ? "Checking" : "Available", systemImage: prediction == nil ? "clock" : "checkmark.seal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(prediction == nil ? Color.secondary : Color.green)
                }

                Text("Predicted public reference structure. Licensed CC BY 4.0; not personalized health data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let prediction {
                    ProteinMetricLine("Entry", prediction.entryID)
                    ProteinMetricLine("Version", prediction.latestVersion.map { "v\($0)" } ?? "Unknown")
                    ProteinMetricLine("Mean confidence", prediction.confidenceAverage.map { String(format: "%.1f pLDDT", $0) } ?? "See structure metadata")
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                NavigationLink(value: AppRoute.viewer(protein.uniprotAccession)) {
                    Label("Open 3D Viewer", systemImage: "cube.transparent")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("Open 3D Viewer")
            }
        }
        .background {
            LinearGradient(colors: [Color.cyan.opacity(0.14), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
                .clipShape(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
        }
    }

    private var keyFacts: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Function")
            GlassCard {
                VStack(alignment: .leading, spacing: MYSpacing.md) {
                    Label("What it does", systemImage: "function")
                        .font(.headline)
                    Text(protein.functionSummary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        ProteinFactTile(symbol: "target", title: "Molecular Role", value: protein.molecularFunction.capitalized, color: .cyan)
                        ProteinFactTile(symbol: "location", title: "Cellular Location", value: protein.cellularLocation, color: .purple)
                        ProteinFactTile(symbol: "circle.hexagongrid", title: "Protein Type", value: protein.proteinType.capitalized, color: .mint)
                    }

                    if !protein.systems.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Biological context")
                                .font(.subheadline.weight(.semibold))
                            Text(contextSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var relatedSystems: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Related Systems")
            ForEach(protein.systems, id: \.self) { id in
                if let system = environment.knowledgeGraph.system(id: id) {
                    NavigationLink(value: AppRoute.system(system.id)) {
                        SearchRow(symbol: system.icon, title: system.name, subtitle: system.shortDescription)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var relatedModules: some View {
        let modules = environment.knowledgeGraph.modules.filter { module in
            protein.systems.contains(module.systemID) || (protein.uniprotAccession == "P68871" && module.id == "hemoglobin-function")
        }

        if !modules.isEmpty {
            VStack(alignment: .leading, spacing: MYSpacing.md) {
                SectionTitle(title: "Learning")
                ForEach(modules) { module in
                    NavigationLink(value: AppRoute.functionModule(module.id)) {
                        SearchRow(symbol: "book.pages", title: module.title, subtitle: module.summary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var healthContext: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Health Context")
            GlassCard {
                VStack(alignment: .leading, spacing: MYSpacing.md) {
                    HStack(alignment: .top, spacing: MYSpacing.md) {
                        Image(systemName: "heart.text.square")
                            .foregroundStyle(.pink)
                            .frame(width: 42, height: 42)
                            .background(.pink.opacity(0.14), in: RoundedRectangle(cornerRadius: MYRadius.sm, style: .continuous))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Why it may appear")
                                .font(.headline)
                            Text("HealthKit categories can make systems related to \(protein.geneSymbol) useful to explore, but Molecyou does not measure your \(protein.geneSymbol) level or activity.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    TodayDataStatusBadge(snapshot: healthSnapshot)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        MetricTile(symbol: "figure.run", title: "Workouts", value: healthSnapshot.workoutsThisWeek.map(String.init) ?? "No data")
                        MetricTile(symbol: "figure.mixed.cardio", title: "Types", value: workoutTypesText)
                        MetricTile(symbol: "flame", title: "Energy", value: UnitFormatter.energy(healthSnapshot.activeEnergyThisWeek))
                        MetricTile(symbol: "moon", title: "Sleep", value: UnitFormatter.sleep(healthSnapshot.averageSleepDuration))
                        MetricTile(symbol: "lungs", title: "Oxygen", value: UnitFormatter.percent(healthSnapshot.oxygenSaturation))
                    }

                    if matchingHealthRecommendations.isEmpty {
                        Text(protein.healthContextSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        VStack(alignment: .leading, spacing: MYSpacing.sm) {
                            Text("Relevant signals")
                                .font(.subheadline.weight(.semibold))
                            ForEach(matchingHealthRecommendations) { recommendation in
                                ProteinHealthReasonCard(
                                    recommendation: recommendation,
                                    system: environment.knowledgeGraph.system(id: recommendation.systemID),
                                    evidence: healthSnapshot.matchingEvidence(for: recommendation.systemID)
                                )
                            }
                        }
                    }

                    Text("This is an educational connection between available HealthKit categories and biology topics. It is not a biomarker reading, protein assay, diagnosis, or treatment recommendation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            DisclaimerCard()
        }
    }

    private var sources: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: MYSpacing.md) {
                ForEach(environment.knowledgeGraph.sources(for: protein)) { source in
                    ProteinSourceCitationCard(source: source, protein: protein, prediction: prediction)
                }
            }
            .padding(.top, MYSpacing.sm)
        } label: {
            SectionTitle(title: "Sources", detail: "\(environment.knowledgeGraph.sources(for: protein).count)")
        }
        .padding(MYSpacing.md)
        .background(Color.myPanel, in: RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
    }

    private func tag(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.myAccent.opacity(0.12), in: Capsule())
            .foregroundStyle(Color.myAccent)
    }

    private func loadPrediction() async {
        do {
            prediction = try await environment.alphaFoldClient.prediction(for: protein.uniprotAccession)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadHealthContext() async {
        let snapshot = await environment.healthProvider.snapshot()
        healthSnapshot = snapshot
        healthRecommendations = environment.contextEngine.evaluate(snapshot: snapshot, interests: Set(UserInterest.allCases))
    }

    private var contextSummary: String {
        let names = protein.systems.compactMap { environment.knowledgeGraph.system(id: $0)?.name }
        guard !names.isEmpty else {
            return "This protein is presented as part of the app's molecular education graph."
        }
        return "\(protein.geneSymbol) is connected to \(names.joined(separator: ", ")), so its role is easiest to understand alongside those broader systems."
    }

    private var workoutTypesText: String {
        healthSnapshot.workoutTypesThisWeek.isEmpty ? "No data" : healthSnapshot.workoutTypesThisWeek.joined(separator: ", ")
    }
}

private struct ProteinFactTile: View {
    let symbol: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: MYRadius.sm, style: .continuous))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            ZStack(alignment: .topTrailing) {
                Color(.tertiarySystemGroupedBackground)
                LinearGradient(colors: [color.opacity(0.18), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
            }
            .clipShape(RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous).stroke(color.opacity(0.16), lineWidth: 1))
    }
}

private struct ProteinHealthReasonCard: View {
    let recommendation: HealthContextRecommendation
    let system: BiologicalSystem?
    let evidence: [HealthContextEvidence]

    private var colors: [Color] {
        system?.accentColors.compactMap(Color.init(hex:)).isEmpty == false
            ? system?.accentColors.compactMap(Color.init(hex:)) ?? [.myAccent, .cyan]
            : [.myAccent, .cyan]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MYSpacing.sm) {
            HStack(spacing: MYSpacing.sm) {
                if let system {
                    GradientIcon(symbol: system.icon, colors: system.accentColors.compactMap(Color.init(hex:)))
                        .frame(width: 38, height: 38)
                    Text(system.name)
                        .font(.subheadline.weight(.semibold))
                } else {
                    Label("Related system", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
                RelevanceBadge(relevance: recommendation.relevance)
            }

            ForEach(recommendation.reasons, id: \.self) { reason in
                Label(reason, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            ForEach(evidence.prefix(2)) { item in
                HStack(alignment: .top, spacing: MYSpacing.sm) {
                    Image(systemName: item.symbol)
                        .foregroundStyle(colors.first ?? .myAccent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(item.title): \(item.value)")
                            .font(.caption.weight(.semibold))
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12)
        .background {
            ZStack(alignment: .topTrailing) {
                Color(.tertiarySystemGroupedBackground)
                LinearGradient(colors: colors.map { $0.opacity(0.14) } + [.clear], startPoint: .topTrailing, endPoint: .bottomLeading)
            }
            .clipShape(RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous).stroke((colors.first ?? .myAccent).opacity(0.14), lineWidth: 1))
    }
}

private struct ProteinSourceCitationCard: View {
    let source: SourceReference
    let protein: Protein
    let prediction: AlphaFoldPrediction?

    private var citationURL: URL? {
        switch source.id {
        case "uniprot":
            URL(string: "https://www.uniprot.org/uniprotkb/\(protein.uniprotAccession)/entry")
        case "alphafold":
            prediction?.entryID.isEmpty == false
                ? URL(string: "https://alphafold.ebi.ac.uk/entry/\(prediction?.entryID ?? "AF-\(protein.uniprotAccession)-F1")")
                : URL(string: "https://alphafold.ebi.ac.uk/entry/AF-\(protein.uniprotAccession)-F1")
        default:
            source.url
        }
    }

    private var actionTitle: String {
        switch source.id {
        case "uniprot": "Open UniProtKB entry"
        case "alphafold": "Open AlphaFold entry"
        default: "Open source"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MYSpacing.sm) {
            Text(source.title)
                .font(.headline)
            Text(source.publisher)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ProteinSourceLine(title: "Citation", value: citationLabel)
                ProteinSourceLine(title: "Reviewed", value: source.reviewedDate)
                if let license = source.license {
                    ProteinSourceLine(title: "License", value: license)
                }
            }

            if let citationURL {
                Link(destination: citationURL) {
                    Label(actionTitle, systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            ZStack(alignment: .leading) {
                Color(.tertiarySystemGroupedBackground)
                Rectangle()
                    .fill(source.id == "alphafold" ? Color.cyan : Color.mint)
                    .frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous))
        }
    }

    private var citationLabel: String {
        switch source.id {
        case "uniprot":
            "\(protein.geneSymbol) · \(protein.uniprotAccession)"
        case "alphafold":
            prediction?.entryID ?? "AF-\(protein.uniprotAccession)-F1"
        default:
            source.title
        }
    }
}

private struct ProteinSourceLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: MYSpacing.md)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct ProteinMetricLine: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer(minLength: MYSpacing.md)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

#Preview("Protein") {
    NavigationStack { ProteinDetailView(environment: .preview, protein: KnowledgeGraphStore.preview.proteins[1]) }
}
