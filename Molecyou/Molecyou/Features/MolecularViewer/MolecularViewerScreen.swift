import SwiftUI

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
    var viewerEvent = "Initializing"

    init(protein: Protein, alphaFoldClient: any AlphaFoldDBProviding, libraryRepository: any LibraryRepository) {
        self.protein = protein
        self.alphaFoldClient = alphaFoldClient
        self.libraryRepository = libraryRepository
    }

    func load() async {
        state = .loading
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
            state = .loaded(url: url, structureText: structureText)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func send(_ command: MolecularViewerCommand) {
        self.command = command
    }
}

struct MolecularViewerScreen: View {
    let environment: AppEnvironment
    let protein: Protein
    @State private var viewModel: MolecularViewerViewModel
    @State private var fullScreen = false

    init(environment: AppEnvironment, protein: Protein) {
        self.environment = environment
        self.protein = protein
        _viewModel = State(initialValue: MolecularViewerViewModel(protein: protein, alphaFoldClient: environment.alphaFoldClient, libraryRepository: environment.libraryRepository))
    }

    var body: some View {
        VStack(spacing: 0) {
            viewerArea
            controls
        }
        .navigationTitle("Hemoglobin Structure".replacingOccurrences(of: "Hemoglobin", with: protein.geneSymbol))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { fullScreen = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .accessibilityLabel("Open full screen viewer")
        }
        .task { await viewModel.load() }
        .fullScreenCover(isPresented: $fullScreen) {
            NavigationStack {
                VStack(spacing: 0) { viewerArea; controls }
                    .toolbar { Button("Done") { fullScreen = false } }
            }
        }
    }

    @ViewBuilder
    private var viewerArea: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Loading AlphaFold reference structure")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MYGradient.darkBackground)
                .foregroundStyle(.white)
        case .loaded(let url, let structureText):
            MolecularViewerWebView(structureURL: url, structureData: structureText, proteinName: protein.name, accession: protein.uniprotAccession, command: viewModel.command) { event in
                viewModel.viewerEvent = event
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading) {
                    Text(protein.name).font(.headline)
                    Text("AlphaFold model · reference structure").font(.caption)
                }
                .padding(12)
                .foregroundStyle(.white)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: MYRadius.md))
                .padding()
            }
            .overlay(alignment: .bottomTrailing) { ConfidenceLegend().padding() }
            .accessibilityLabel("Three-dimensional predicted structure of \(protein.name), shown as \(viewModel.representation.rawValue) and colored by \(viewModel.colorMode.rawValue.lowercased()).")
        case .failed(let message):
            ErrorStateView(title: "Structure unavailable", message: message, actionTitle: "Retry") { Task { await viewModel.load() } }
        }
    }

    private var controls: some View {
        VStack(spacing: MYSpacing.sm) {
            HStack {
                Button { viewModel.send(.resetCamera) } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                Button { viewModel.send(.centerStructure) } label: { Label("Center", systemImage: "scope") }
                Toggle(isOn: Binding(get: { viewModel.labelsEnabled }, set: { newValue in viewModel.labelsEnabled = newValue; viewModel.send(.toggleLabels(newValue)) })) {
                    Label("Labels", systemImage: "tag")
                }
                .toggleStyle(.button)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Picker("Representation", selection: Binding(get: { viewModel.representation }, set: { value in viewModel.representation = value; viewModel.send(.setRepresentation(value)); environment.analytics.track(AnalyticsEvent(name: "viewer_representation_changed", properties: ["representation": value.rawValue])) })) {
                ForEach(RepresentationType.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Color", selection: Binding(get: { viewModel.colorMode }, set: { value in viewModel.colorMode = value; viewModel.send(.setColorMode(value)) })) {
                ForEach(ColorMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(MYSpacing.md)
        .background(Color.myPanel)
    }
}

struct ConfidenceLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Confidence").font(.caption.bold())
            LinearGradient(colors: [.red, .orange, .yellow, .green, .blue], startPoint: .leading, endPoint: .trailing)
                .frame(width: 150, height: 8)
                .clipShape(Capsule())
            HStack { Text("Low"); Spacer(); Text("High") }
                .font(.caption2)
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: MYRadius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Structure confidence legend from low to high")
    }
}

#Preview("Viewer") {
    NavigationStack { MolecularViewerScreen(environment: .preview, protein: KnowledgeGraphStore.preview.proteins[1]) }
}
