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
                KeyProcessRow(pathway: pathway)
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

    private var palette: [Color] {
        ThumbnailPalette.colors(for: protein.uniprotAccession)
    }

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
        .background {
            LinearGradient(colors: [palette.first?.opacity(0.14) ?? Color.myAccent.opacity(0.14), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LinearGradient(colors: palette, startPoint: .top, endPoint: .bottom))
                .frame(width: 4)
                .padding(.vertical, 12)
        }
    }
}

struct ProteinThumbnail: View {
    let accession: String

    private var palette: [Color] {
        ThumbnailPalette.colors(for: accession)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous)
                .fill(LinearGradient(colors: palette.map { $0.opacity(0.95) }, startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 26, height: 26)
                .offset(x: 18, y: -18)
            ProteinRibbonMotif(seed: accession, colors: palette)
                .padding(8)
        }
        .frame(width: 58, height: 58)
        .shadow(color: (palette.first ?? .myAccent).opacity(0.22), radius: 10, x: 0, y: 5)
        .accessibilityHidden(true)
    }
}

struct KeyProcessRow: View {
    let pathway: Pathway

    var body: some View {
        GlassCard {
            HStack(spacing: MYSpacing.md) {
                ProcessThumbnail(pathway: pathway)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pathway.name).font(.headline)
                    Text(pathway.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
            }
        }
    }
}

struct ProcessThumbnail: View {
    let pathway: Pathway

    private var colors: [Color] {
        ThumbnailPalette.colors(for: pathway.id + pathway.name)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous)
                .fill(Color.myInk)
            ProcessNetworkMotif(seed: pathway.id, colors: colors)
                .padding(8)
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
    }
}

struct HealthContextThumbnail: View {
    let system: BiologicalSystem

    private var colors: [Color] {
        let resolved = system.accentColors.compactMap(Color.init(hex:))
        return resolved.isEmpty ? ThumbnailPalette.colors(for: system.id) : resolved
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            HealthContextMotif(seed: system.id, symbol: system.icon, colors: colors)
                .padding(8)
            RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
        }
        .frame(width: 64, height: 64)
        .shadow(color: (colors.first ?? .myAccent).opacity(0.22), radius: 10, x: 0, y: 5)
        .accessibilityHidden(true)
    }
}

private struct HealthContextMotif: View {
    let seed: String
    let symbol: String
    let colors: [Color]

    var body: some View {
        Canvas { context, size in
            let values = ThumbnailPalette.values(for: seed, count: 8)
            var points: [CGPoint] = []
            for index in 0..<5 {
                let column = CGFloat(index % 3)
                let row = CGFloat(index / 3)
                let xOffset = CGFloat(0.18) + column * CGFloat(0.32) + values[index] * CGFloat(0.06)
                let yOffset = CGFloat(0.20) + row * CGFloat(0.36) + values[index + 2] * CGFloat(0.10)
                points.append(CGPoint(x: size.width * xOffset, y: size.height * yOffset))
            }

            var path = Path()
            for index in points.indices.dropLast() {
                path.move(to: points[index])
                path.addLine(to: points[index + 1])
            }
            path.move(to: points[0])
            path.addLine(to: points[3])
            context.stroke(path, with: .color(.white.opacity(0.44)), lineWidth: 1.4)

            for (index, point) in points.enumerated() {
                let radius = 4 + values[index + 3] * 2
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(colors[index % colors.count].opacity(0.92))
                )
            }
        }
        .overlay {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
        }
    }
}

struct ProteinRibbonMotif: View {
    let seed: String
    let colors: [Color]

    var body: some View {
        Canvas { context, size in
            let values = ThumbnailPalette.values(for: seed, count: 8)
            var path = Path()
            for index in 0..<6 {
                let x = size.width * CGFloat(index) / 5
                let y = size.height * (0.28 + values[index] * 0.44)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - size.width * 0.1, y: size.height * (0.15 + values[index + 1] * 0.7)))
                }
            }

            context.stroke(path, with: .linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), lineWidth: 4)

            for index in 0..<4 {
                let point = CGPoint(x: size.width * (0.18 + CGFloat(index) * 0.21), y: size.height * (0.22 + values[index + 2] * 0.56))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)), with: .color(colors[index % colors.count]))
            }
        }
    }
}

struct ProcessNetworkMotif: View {
    let seed: String
    let colors: [Color]

    var body: some View {
        Canvas { context, size in
            let values = ThumbnailPalette.values(for: seed, count: 10)
            let points: [CGPoint] = (0..<5).map { index in
                let column = CGFloat(index % 3)
                let row = CGFloat(index / 3)
                let xOffset = CGFloat(0.18) + column * CGFloat(0.31) + values[index] * CGFloat(0.08)
                let yOffset = CGFloat(0.18) + row * CGFloat(0.34) + values[index + 3] * CGFloat(0.12)
                return CGPoint(x: size.width * xOffset, y: size.height * yOffset)
            }

            var path = Path()
            for index in points.indices.dropLast() {
                path.move(to: points[index])
                path.addLine(to: points[index + 1])
            }
            path.move(to: points[0])
            path.addLine(to: points[3])
            path.move(to: points[1])
            path.addLine(to: points[4])
            context.stroke(path, with: .color(.white.opacity(0.42)), lineWidth: 1.5)

            for (index, point) in points.enumerated() {
                let radius = 4 + values[index + 5] * 3
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(colors[index % colors.count]))
            }
        }
    }
}

enum ThumbnailPalette {
    static func colors(for seed: String) -> [Color] {
        let palettes: [[Color]] = [
            [.cyan, .blue, .mint],
            [.pink, .purple, .cyan],
            [.orange, .red, .pink],
            [.green, .teal, .blue],
            [.indigo, .cyan, .green],
            [.yellow, .orange, .purple]
        ]
        return palettes[index(for: seed, modulo: palettes.count)]
    }

    static func values(for seed: String, count: Int) -> [CGFloat] {
        let base = stableNumber(for: seed)
        return (0..<count).map { index in
            let value = (base + index * 37 + index * index * 11) % 97
            return CGFloat(value) / 96
        }
    }

    private static func index(for seed: String, modulo: Int) -> Int {
        stableNumber(for: seed) % modulo
    }

    private static func stableNumber(for seed: String) -> Int {
        seed.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0x7fffffff
        }
    }
}

struct HealthContextView: View {
    let environment: AppEnvironment
    let system: BiologicalSystem
    @State private var snapshot = HealthSnapshot.empty(isDemo: true)
    @State private var recommendation: HealthContextRecommendation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                hero
                reasonsSection
                matchedEvidenceSection
                categoriesSection
                boundarySection
            }
            .padding(MYSpacing.md)
        }
        .navigationTitle("Health Context")
        .moleculeScreenBackground()
        .task {
            snapshot = await environment.healthProvider.snapshot()
            recommendation = environment.contextEngine.evaluate(snapshot: snapshot, interests: Set(UserInterest.allCases)).first { $0.systemID == system.id }
        }
    }

    private var colors: [Color] {
        let resolved = system.accentColors.compactMap(Color.init(hex:))
        return resolved.isEmpty ? [.myAccent, .cyan] : resolved
    }

    private var hero: some View {
        GlassCard {
            HStack(alignment: .top, spacing: MYSpacing.md) {
                HealthContextThumbnail(system: system)
                VStack(alignment: .leading, spacing: 8) {
                    Text(system.name)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Relevant HealthKit context")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.first ?? .myAccent)
                    Text("Available HealthKit categories can make this topic useful to explore, but Molecyou does not measure proteins or diagnose health conditions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    TodayDataStatusBadge(snapshot: snapshot)
                }
                Spacer(minLength: 0)
            }
        }
        .background {
            LinearGradient(colors: [colors.first?.opacity(0.16) ?? Color.myAccent.opacity(0.16), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                .frame(width: 4)
                .padding(.vertical, 14)
        }
    }

    private var reasonsSection: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Why this appeared")
            GlassCard {
                VStack(alignment: .leading, spacing: MYSpacing.sm) {
                    ForEach(snapshot.matchingEvidence(for: system.id)) { evidence in
                        Label(evidence.detail, systemImage: evidence.symbol)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let recommendation {
                        Divider()
                        ForEach(recommendation.reasons, id: \.self) { reason in
                            Label(reason, systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let recommendation {
                        RelevanceBadge(relevance: recommendation.relevance)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    private var matchedEvidenceSection: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Matched values")
            LazyVStack(spacing: MYSpacing.sm) {
                ForEach(snapshot.matchingEvidence(for: system.id)) { evidence in
                    HealthEvidenceCard(evidence: evidence, colors: colors)
                }
            }
            Text("HealthKit currently provides summary categories here, such as workout count or weekly active energy. It does not expose the exact individual workout that caused this match in Molecyou.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Available categories")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                MetricTile(symbol: "figure.run", title: "Workouts", value: snapshot.workoutsThisWeek.map(String.init) ?? "No data")
                MetricTile(symbol: "figure.mixed.cardio", title: "Workout Types", value: workoutTypesText)
                MetricTile(symbol: "flame", title: "Energy", value: UnitFormatter.energy(snapshot.activeEnergyThisWeek))
                MetricTile(symbol: "heart", title: "Resting HR", value: UnitFormatter.heartRate(snapshot.restingHeartRate))
                MetricTile(symbol: "moon", title: "Sleep", value: UnitFormatter.sleep(snapshot.averageSleepDuration))
                MetricTile(symbol: "lungs", title: "Oxygen", value: UnitFormatter.percent(snapshot.oxygenSaturation))
            }
        }
    }

    private var boundarySection: some View {
        GlassCard {
            Label {
                Text("This page connects HealthKit categories to educational biology topics. It is not measuring \(system.name.lowercased()) proteins, estimating molecular activity, diagnosing a condition, or recommending treatment.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(colors.first ?? .myAccent)
            }
        }
    }

    private var workoutTypesText: String {
        snapshot.workoutTypesThisWeek.isEmpty ? "No data" : snapshot.workoutTypesThisWeek.joined(separator: ", ")
    }
}

struct HealthEvidenceCard: View {
    let evidence: HealthContextEvidence
    let colors: [Color]

    private var color: Color {
        colors.first ?? .myAccent
    }

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: MYSpacing.md) {
                Image(systemName: evidence.symbol)
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: MYRadius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(evidence.title)
                            .font(.headline)
                        Spacer(minLength: MYSpacing.md)
                        Text(evidence.value)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(color)
                    }
                    Text(evidence.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .background {
            LinearGradient(colors: [color.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
        }
    }
}

struct FunctionExplanationView: View {
    let environment: AppEnvironment
    let module: EducationModule
    @State private var showingSources = false

    private var sources: [SourceReference] {
        environment.knowledgeGraph.sources(for: module)
    }

    private var citedProteins: [Protein] {
        environment.knowledgeGraph.proteins(for: module)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                topicHeader
                topicInformation
                TopicStepTimeline(steps: module.steps)
                DisclaimerCard()
            }
            .padding(MYSpacing.md)
        }
        .navigationTitle(module.title)
        .moleculeScreenBackground()
        .sheet(isPresented: $showingSources) {
            TopicSourcesSheet(module: module, sources: sources, proteins: citedProteins)
                .presentationDetents([.medium, .large])
        }
    }

    private var topicHeader: some View {
        Text(module.summary)
            .font(.headline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var topicInformation: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Information")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                TopicInfoTile(symbol: "book.pages", title: "Lesson Type", value: "Step-by-step")
                TopicInfoTile(symbol: "number", title: "Steps", value: "\(module.steps.count)")
                Button {
                    showingSources = true
                } label: {
                    TopicInfoTile(symbol: "checkmark.seal", title: "Sources", value: formattedSources, accessory: "chevron.up.forward")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var formattedSources: String {
        sources
            .map(\.title)
            .joined(separator: ", ")
    }
}

private struct TopicInfoTile: View {
    let symbol: String
    let title: String
    let value: String
    var accessory: String?

    private var color: Color {
        switch title {
        case "Lesson Type": .cyan
        case "Steps": .purple
        case "Sources": .mint
        default: .myAccent
        }
    }

    var body: some View {
        HStack(spacing: MYSpacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: MYRadius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
            if let accessory {
                Image(systemName: accessory)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(MYSpacing.md)
        .background {
            ZStack(alignment: .topTrailing) {
                Color.myPanel
                LinearGradient(colors: [color.opacity(0.14), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
            }
            .clipShape(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous).stroke(color.opacity(0.12), lineWidth: 1))
    }
}

private struct TopicSourcesSheet: View {
    let module: EducationModule
    let sources: [SourceReference]
    let proteins: [Protein]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MYSpacing.lg) {
                    Text("These are the specific UniProtKB entries used as citations for this lesson's educational summary and steps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if proteins.isEmpty {
                        LibraryEmptyCard(symbol: "checkmark.seal", title: "No specific citations", message: "This lesson has source metadata, but no protein-level citations are mapped in the local knowledge graph.")
                    } else {
                        LazyVStack(spacing: MYSpacing.sm) {
                            ForEach(proteins) { protein in
                                TopicProteinCitationCard(protein: protein, source: primaryUniProtSource)
                            }
                        }
                    }

                    if !sources.isEmpty {
                        sourceMetadata
                    }
                }
                .padding(MYSpacing.md)
            }
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .moleculeScreenBackground()
        }
    }

    private var primaryUniProtSource: SourceReference? {
        sources.first { $0.id == "uniprot" } ?? sources.first
    }

    private var sourceMetadata: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Source Metadata")
            LazyVStack(spacing: MYSpacing.sm) {
                ForEach(sources) { source in
                    TopicSourceMetadataCard(source: source)
                }
            }
        }
    }
}

private struct TopicProteinCitationCard: View {
    let protein: Protein
    let source: SourceReference?

    private var url: URL? {
        URL(string: "https://www.uniprot.org/uniprotkb/\(protein.uniprotAccession)/entry")
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: MYSpacing.sm) {
                HStack(alignment: .top, spacing: MYSpacing.md) {
                    ProteinThumbnail(accession: protein.uniprotAccession)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(protein.name)
                            .font(.headline)
                        Text("\(protein.geneSymbol) · \(protein.uniprotAccession)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                Text(protein.functionSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    if let source {
                        CitationLine(title: "Database", value: source.title)
                        CitationLine(title: "Publisher", value: source.publisher)
                        CitationLine(title: "Reviewed", value: source.reviewedDate)
                    }
                    if let license = source?.license {
                        CitationLine(title: "License", value: license)
                    }
                }

                if let url {
                    Link(destination: url) {
                        Label("Open UniProtKB entry", systemImage: "arrow.up.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

private struct TopicSourceMetadataCard: View {
    let source: SourceReference

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: MYSpacing.sm) {
                Text(source.title)
                    .font(.headline)
                Text(source.publisher)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    CitationLine(title: "Reviewed", value: source.reviewedDate)
                    if let license = source.license {
                        CitationLine(title: "License", value: license)
                    }
                }

                if let url = source.url {
                    Link(destination: url) {
                        Label("Open database home", systemImage: "arrow.up.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

private struct CitationLine: View {
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
        }
    }
}

private struct TopicStepTimeline: View {
    let steps: [EducationStep]

    var body: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Steps")
            if steps.isEmpty {
                LibraryEmptyCard(symbol: "book.pages", title: "Lesson in brief", message: "This topic currently has a short summary only.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        TopicStepRow(index: index, step: step, isLast: index == steps.count - 1)
                    }
                }
                .padding(.vertical, MYSpacing.sm)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            }
        }
    }
}

private struct TopicStepRow: View {
    let index: Int
    let step: EducationStep
    let isLast: Bool

    private var color: Color {
        [.myAccent, .cyan, .mint, .pink, .orange][index % 5]
    }

    var body: some View {
        HStack(alignment: .top, spacing: MYSpacing.md) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(color)
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)

                if !isLast {
                    Rectangle()
                        .fill(color.opacity(0.24))
                        .frame(width: 2, height: 48)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(step.title, systemImage: step.symbol)
                    .font(.headline)
                    .foregroundStyle(color)
                Text(step.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : MYSpacing.lg)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, MYSpacing.md)
        .padding(.top, index == 0 ? MYSpacing.sm : 0)
        .padding(.bottom, isLast ? MYSpacing.sm : 0)
    }
}

#Preview("System Detail") {
    NavigationStack { SystemDetailView(environment: .preview, system: KnowledgeGraphStore.preview.systems[0]) }
}
