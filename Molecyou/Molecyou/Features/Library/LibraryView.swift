import SwiftUI

struct LibraryView: View {
    let environment: AppEnvironment
    @State private var query = ""
    @State private var noteText = ""
    @State private var selectedProtein: Protein?

    private var savedProteins: [Protein] {
        environment.knowledgeGraph.proteins
            .filter { environment.libraryRepository.savedProteinAccessions.contains($0.uniprotAccession) }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.geneSymbol.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            Section("Saved Proteins") {
                if savedProteins.isEmpty {
                    ContentUnavailableView("Library is empty", systemImage: "bookmark", description: Text("Save proteins from their detail page to collect them here."))
                } else {
                    ForEach(savedProteins) { protein in
                        NavigationLink(value: AppRoute.protein(protein.uniprotAccession)) {
                            HStack { ProteinThumbnail(accession: protein.uniprotAccession); VStack(alignment: .leading) { Text(protein.name); Text(protein.geneSymbol).font(.caption).foregroundStyle(.secondary) } }
                        }
                    }
                }
            }
            Section("Downloaded Structures") {
                if environment.libraryRepository.downloadedProteinAccessions.isEmpty {
                    Label("No downloaded structures", systemImage: "icloud.and.arrow.down")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(environment.libraryRepository.downloadedProteinAccessions).sorted(), id: \.self) { accession in
                        Text(accession)
                    }
                }
                Button(role: .destructive) {
                    try? environment.libraryRepository.clearCachedStructures()
                    Task { try? await environment.structureCache.clear() }
                } label: {
                    Label("Clear downloaded structures", systemImage: "trash")
                }
                .accessibilityIdentifier("Clear downloaded structures")
            }
            Section("Notes") {
                TextField("Add an educational note", text: $noteText, axis: .vertical)
                Button("Add Note") {
                    environment.libraryRepository.addNote(itemID: "general", itemType: "note", text: noteText)
                    noteText = ""
                }
                ForEach(environment.libraryRepository.notes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.text)
                        Text(note.updatedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                    .swipeActions { Button("Delete", role: .destructive) { environment.libraryRepository.deleteNote(note) } }
                }
            }
        }
        .navigationTitle("Library")
        .searchable(text: $query, prompt: "Search saved items")
        .onAppear { environment.libraryRepository.refresh() }
    }
}

#Preview("Library") {
    NavigationStack { LibraryView(environment: .preview) }
}
