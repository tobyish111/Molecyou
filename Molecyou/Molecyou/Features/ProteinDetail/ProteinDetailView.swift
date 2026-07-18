import SwiftUI

enum ProteinDetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case structure = "Structure"
    case function = "Function"
    case health = "Health Context"
    case sources = "Sources"
    var id: String { rawValue }
}

struct ProteinDetailView: View {
    let environment: AppEnvironment
    let protein: Protein
    @State private var selectedTab: ProteinDetailTab = .overview
    @State private var prediction: AlphaFoldPrediction?
    @State private var errorMessage: String?
    @State private var noteText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                header
                Picker("Section", selection: $selectedTab) {
                    ForEach(ProteinDetailTab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                }
                .pickerStyle(.segmented)
                tabContent
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
        }
        .moleculeScreenBackground()
        .task {
            environment.libraryRepository.addRecent(itemID: protein.uniprotAccession, itemType: "protein")
            await loadPrediction()
        }
    }

    private var header: some View {
        GlassCard {
            HStack(alignment: .top, spacing: MYSpacing.md) {
                ProteinThumbnail(accession: protein.uniprotAccession)
                VStack(alignment: .leading, spacing: 6) {
                    Text(protein.name).font(.title2.bold())
                    Text("\(protein.geneSymbol) · \(protein.uniprotAccession)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.myAccent)
                    Text(protein.organism).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview: overview
        case .structure: structure
        case .function: function
        case .health: health
        case .sources: sources
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            InfoGrid(items: [
                ("Function", protein.functionSummary),
                ("Cellular location", protein.cellularLocation),
                ("Molecular function", protein.molecularFunction.capitalized),
                ("Protein type", protein.proteinType.capitalized)
            ])
            Text("Related systems")
                .font(.headline)
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

    private var structure: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            GlassCard {
                VStack(alignment: .leading, spacing: MYSpacing.md) {
                    HStack {
                        Text("AlphaFold DB")
                            .font(.headline)
                        Spacer()
                        Label(prediction == nil ? "Checking" : "Available", systemImage: prediction == nil ? "clock" : "checkmark.seal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(prediction == nil ? Color.secondary : Color.green)
                    }
                    Text("Predicted structure provided by AlphaFold Protein Structure Database. AlphaFold DB data is licensed under CC BY 4.0. This is a public reference structure, not a personalized structure.")
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
                }
            }
        }
    }

    private var function: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            Text(protein.functionSummary).foregroundStyle(.secondary)
            if protein.uniprotAccession == "P68871", let module = environment.knowledgeGraph.module(id: "hemoglobin-function") {
                NavigationLink(value: AppRoute.functionModule(module.id)) {
                    SearchRow(symbol: "book.pages", title: module.title, subtitle: module.summary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var health: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How HealthKit relates")
                        .font(.headline)
                    Text("Recent aerobic workouts make oxygen transport relevant to explore. \(protein.name) is generally involved in \(protein.molecularFunction), but this app does not measure your \(protein.geneSymbol) level or activity.")
                        .foregroundStyle(.secondary)
                }
            }
            DisclaimerCard()
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            ForEach(environment.knowledgeGraph.sources(for: protein)) { source in
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(source.title).font(.headline)
                        Text(source.publisher).font(.subheadline).foregroundStyle(.secondary)
                        if let license = source.license { Text("License: \(license)").font(.caption).foregroundStyle(.secondary) }
                        Text("Last content-review date: \(source.reviewedDate)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func loadPrediction() async {
        do {
            prediction = try await environment.alphaFoldClient.prediction(for: protein.uniprotAccession)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary) }
            .font(.caption)
    }
}

struct InfoGrid: View {
    let items: [(String, String)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            ForEach(items, id: \.0) { title, value in
                GlassCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(.caption).foregroundStyle(.secondary)
                        Text(value).font(.headline).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview("Protein") {
    NavigationStack { ProteinDetailView(environment: .preview, protein: KnowledgeGraphStore.preview.proteins[1]) }
}
