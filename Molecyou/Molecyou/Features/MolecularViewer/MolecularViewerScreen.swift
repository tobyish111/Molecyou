import SwiftUI

struct ProteinStructurePart: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let chainID: String
    let startSequenceNumber: Int
    let endSequenceNumber: Int
    let residueCount: Int

    var focusSequenceNumber: Int {
        (startSequenceNumber + endSequenceNumber) / 2
    }

    static func make(from structureText: String) -> [ProteinStructurePart] {
        guard let atoms = try? MMCIFAtomParser.parse(structureText) else { return [] }
        let grouped = Dictionary(grouping: atoms.compactMap { atom -> (String, Int)? in
            guard let sequenceNumber = atom.sequenceNumber else { return nil }
            return (atom.chainID, sequenceNumber)
        }, by: { $0.0 })

        return grouped.keys.sorted().flatMap { chainID in
            let residues = Array(Set(grouped[chainID]?.map(\.1) ?? [])).sorted()
            guard !residues.isEmpty else { return [ProteinStructurePart]() }

            let targetSegmentCount = min(max(residues.count / 35, 4), 8)
            let segmentSize = max(Int(ceil(Double(residues.count) / Double(targetSegmentCount))), 1)

            return stride(from: 0, to: residues.count, by: segmentSize).enumerated().map { index, startIndex in
                let endIndex = min(startIndex + segmentSize - 1, residues.count - 1)
                let start = residues[startIndex]
                let end = residues[endIndex]
                let count = endIndex - startIndex + 1
                let title = residues.count > segmentSize ? "Chain \(chainID) part \(index + 1)" : "Chain \(chainID)"
                let subtitle = start == end ? "Residue \(start)" : "Residues \(start)-\(end)"
                return ProteinStructurePart(
                    id: "\(chainID)-\(start)-\(end)",
                    title: title,
                    subtitle: subtitle,
                    chainID: chainID,
                    startSequenceNumber: start,
                    endSequenceNumber: end,
                    residueCount: count
                )
            }
        }
    }
}

@MainActor
@Observable
final class MolecularViewerViewModel {
    enum State: Equatable {
        case loading
        case loaded(url: URL, structureText: String)
        case failed(String)
    }

    let protein: Protein
    private let alphaFoldClient: any AlphaFoldDBProviding
    private let libraryRepository: any LibraryRepository
    var state: State = .loading
    var representation: RepresentationType = .ribbon
    var colorMode: ColorMode = .confidence
    var labelsEnabled = false
    var command: MolecularViewerCommand?
    var commandSequence = 0
    var viewerEvent = "Preparing native structure renderer"
    var parts: [ProteinStructurePart] = []

    init(protein: Protein, alphaFoldClient: any AlphaFoldDBProviding, libraryRepository: any LibraryRepository) {
        self.protein = protein
        self.alphaFoldClient = alphaFoldClient
        self.libraryRepository = libraryRepository
    }

    func load() async {
        state = .loading
        parts = []
        do {
            let prediction = try await alphaFoldClient.prediction(for: protein.uniprotAccession)
            let url = try await alphaFoldClient.downloadStructure(for: prediction, format: .mmcif)
            let data = try Data(contentsOf: url)
            guard let structureText = String(data: data, encoding: .utf8), !structureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                state = .failed("The cached AlphaFold structure file could not be read as mmCIF text.")
                return
            }
            let bytes = ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? data.count)
            libraryRepository.recordCachedStructure(accession: protein.uniprotAccession, url: url, format: .mmcif, bytes: bytes)
            parts = ProteinStructurePart.make(from: structureText)
            state = .loaded(url: url, structureText: structureText)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func send(_ command: MolecularViewerCommand) {
        self.command = command
        commandSequence += 1
    }
}

struct MolecularViewerScreen: View {
    let environment: AppEnvironment
    let protein: Protein
    @State private var viewModel: MolecularViewerViewModel
    @State private var fullScreen = false
    @State private var selectedPartID: ProteinStructurePart.ID?

    init(environment: AppEnvironment, protein: Protein) {
        self.environment = environment
        self.protein = protein
        _viewModel = State(initialValue: MolecularViewerViewModel(protein: protein, alphaFoldClient: environment.alphaFoldClient, libraryRepository: environment.libraryRepository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                viewerCard
                controls
                sourceNote
            }
            .padding(MYSpacing.md)
        }
        .navigationTitle("\(protein.geneSymbol) Structure")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { fullScreen = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .accessibilityLabel("Open full screen viewer")
        }
        .moleculeScreenBackground()
        .task { await viewModel.load() }
        .fullScreenCover(isPresented: $fullScreen) {
            fullScreenViewer
        }
    }

    private var fullScreenViewer: some View {
        ZStack {
            viewerAreaContent(showChrome: false)
                .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    fullScreenPartsMenu
                    Spacer()
                    Button { fullScreen = false } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.42), in: Circle())
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Close full screen viewer")
                }
                Spacer()
            }
            .padding(.horizontal, MYSpacing.md)
            .padding(.top, MYSpacing.md)
        }
        .background(MYGradient.darkBackground.ignoresSafeArea())
    }

    private var fullScreenPartsMenu: some View {
        Menu {
            if viewModel.parts.isEmpty {
                Button("Parts loading") { }
                    .disabled(true)
            } else {
                ForEach(viewModel.parts) { part in
                    Button {
                        select(part)
                    } label: {
                        Label("\(part.title), \(part.subtitle)", systemImage: selectedPartID == part.id ? "scope" : "point.3.connected.trianglepath.dotted")
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.headline.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(.black.opacity(0.42), in: Circle())
                .foregroundStyle(.white)
        }
        .accessibilityLabel("Protein parts")
        .accessibilityIdentifier("Full Screen Protein Parts Menu")
    }

    private var viewerCard: some View {
        VStack(alignment: .leading, spacing: MYSpacing.sm) {
            viewerArea
                .frame(height: 430)
                .clipShape(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(protein.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(protein.geneSymbol) · \(protein.uniprotAccession)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.myAccent)
                }
                Spacer()
                Label("AlphaFold", systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
    }

    private var viewerArea: some View {
        viewerAreaContent(showChrome: true)
    }

    @ViewBuilder
    private func viewerAreaContent(showChrome: Bool) -> some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Loading AlphaFold reference structure")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MYGradient.darkBackground)
                .foregroundStyle(.white)
        case .loaded(_, let structureText):
            NativeMolecularViewerView(
                structureData: structureText,
                proteinName: protein.name,
                representation: viewModel.representation,
                colorMode: viewModel.colorMode,
                labelsEnabled: viewModel.labelsEnabled,
                command: viewModel.command,
                commandSequence: viewModel.commandSequence
            ) { event in
                viewModel.viewerEvent = event
            }
            .overlay(alignment: .topLeading) {
                if showChrome {
                    ViewerHeaderOverlay(protein: protein)
                        .padding(MYSpacing.md)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if showChrome {
                    ViewerStatusOverlay(message: viewModel.viewerEvent)
                        .padding(MYSpacing.md)
                }
            }
            .accessibilityLabel("Three-dimensional predicted structure of \(protein.name), shown as \(viewModel.representation.rawValue) and colored by \(viewModel.colorMode.rawValue.lowercased()).")
        case .failed(let message):
            ErrorStateView(title: "Structure unavailable", message: message, actionTitle: "Retry") { Task { await viewModel.load() } }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            HStack(spacing: MYSpacing.sm) {
                Button { clearSelectionAndSend(.resetCamera) } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                    .accessibilityLabel("Reset camera")
                Button { clearSelectionAndSend(.centerStructure) } label: { Label("Center", systemImage: "scope") }
                    .accessibilityLabel("Center structure")
                Toggle(isOn: Binding(get: { viewModel.labelsEnabled }, set: { newValue in viewModel.labelsEnabled = newValue; viewModel.send(.toggleLabels(newValue)) })) {
                    Label("Labels", systemImage: "tag")
                }
                .toggleStyle(.button)
                .accessibilityLabel("Toggle residue labels")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            ViewerOptionGrid(
                title: "Representation",
                options: RepresentationType.allCases,
                selection: Binding(get: { viewModel.representation }, set: { value in
                    viewModel.representation = value
                    viewModel.send(.setRepresentation(value))
                    environment.analytics.track(AnalyticsEvent(name: "viewer_representation_changed", properties: ["representation": value.rawValue]))
                }),
                label: \.rawValue
            )

            proteinParts

            ViewerOptionGrid(
                title: "Color",
                options: ColorMode.allCases,
                selection: Binding(get: { viewModel.colorMode }, set: { value in
                    viewModel.colorMode = value
                    viewModel.send(.setColorMode(value))
                }),
                label: \.rawValue
            )
        }
        .padding(MYSpacing.md)
        .background(Color.myPanel, in: RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
    }

    private var proteinParts: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Protein Parts", detail: viewModel.parts.isEmpty ? nil : "\(viewModel.parts.count)")

            if viewModel.parts.isEmpty {
                Label("Parts appear after the structure loads", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(MYSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.myPanel, in: RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.parts) { part in
                        ProteinPartRow(part: part, isSelected: selectedPartID == part.id, isDimmed: selectedPartID != nil && selectedPartID != part.id) {
                            select(part)
                        }
                    }
                }
            }
        }
    }

    private var sourceNote: some View {
        Label("AlphaFold structures are public predicted references and are not personalized measurements.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func select(_ part: ProteinStructurePart) {
        selectedPartID = part.id
        viewModel.send(.focusRegion(chainID: part.chainID, startSequenceNumber: part.startSequenceNumber, endSequenceNumber: part.endSequenceNumber, label: part.title))
        environment.analytics.track(AnalyticsEvent(name: "viewer_part_selected", properties: ["protein": protein.uniprotAccession, "part": part.id]))
    }

    private func clearSelectionAndSend(_ command: MolecularViewerCommand) {
        selectedPartID = nil
        viewModel.send(command)
    }
}

struct ProteinPartRow: View {
    let part: ProteinStructurePart
    let isSelected: Bool
    let isDimmed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MYSpacing.md) {
                Image(systemName: isSelected ? "scope" : "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(isSelected ? Color.white : isDimmed ? Color.secondary : Color.myAccent)
                    .frame(width: 38, height: 38)
                    .background(isSelected ? Color.myAccent : (isDimmed ? Color.secondary.opacity(0.12) : Color.myAccent.opacity(0.12)), in: RoundedRectangle(cornerRadius: MYRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(part.title)
                        .font(.headline)
                        .foregroundStyle(isDimmed ? .secondary : .primary)
                    Text("\(part.subtitle) · \(part.residueCount) residues")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(MYSpacing.md)
            .background(isSelected ? Color.myAccent.opacity(0.14) : (isDimmed ? Color(.tertiarySystemGroupedBackground) : Color.myPanel), in: RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous).stroke(isSelected ? Color.myAccent.opacity(0.45) : Color.clear, lineWidth: 1))
            .opacity(isDimmed ? 0.58 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Protein Part \(part.id)")
    }
}

struct ViewerOptionGrid<Option: Hashable & Identifiable>: View {
    let title: String
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(options) { option in
                    Button {
                        selection = option
                    } label: {
                        Text(label(option))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(selection == option ? Color.myAccent.opacity(0.2) : Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(selection == option ? Color.myAccent : Color.primary.opacity(0.76))
                            .overlay(Capsule().stroke(selection == option ? Color.myAccent.opacity(0.45) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            }
        }
    }
}

struct ViewerHeaderOverlay: View {
    let protein: Protein

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "cube.transparent")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan)
                Text("AlphaFold reference")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            Text(protein.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Text("\(protein.geneSymbol) · \(protein.uniprotAccession)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: 245, alignment: .leading)
        .padding(12)
        .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

struct ViewerStatusOverlay: View {
    let message: String

    private var isFailure: Bool {
        message.localizedCaseInsensitiveContains("failed") || message.localizedCaseInsensitiveContains("error")
    }

    private var displayMessage: String {
        switch message {
        case "ready": "Viewer ready"
        case let text where text.hasPrefix("loaded:"): text.replacingOccurrences(of: "loaded:", with: "Rendered:")
        case let text where text.hasPrefix("failed:"): text.replacingOccurrences(of: "failed:", with: "Viewer issue:")
        default: message
        }
    }

    var body: some View {
        Label(displayMessage, systemImage: isFailure ? "exclamationmark.triangle.fill" : "cube.transparent")
            .font(.caption.weight(.semibold))
            .lineLimit(3)
            .minimumScaleFactor(0.78)
            .foregroundStyle(.white)
            .frame(maxWidth: 240, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isFailure ? Color.red.opacity(0.72) : Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: MYRadius.md))
            .accessibilityLabel(displayMessage)
    }
}

#Preview("Viewer") {
    NavigationStack { MolecularViewerScreen(environment: .preview, protein: KnowledgeGraphStore.preview.proteins[1]) }
}
