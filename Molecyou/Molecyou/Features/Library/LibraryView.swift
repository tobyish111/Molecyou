import SwiftUI

struct LibraryView: View {
    let environment: AppEnvironment
    @State private var showingClearCacheConfirmation = false

    private var savedProteins: [Protein] {
        environment.knowledgeGraph.proteins
            .filter { environment.libraryRepository.savedProteinAccessions.contains($0.uniprotAccession) }
    }

    private var downloadedAccessions: [String] {
        Array(environment.libraryRepository.downloadedProteinAccessions).sorted()
    }

    private var storageText: String {
        ByteCountFormatter.string(fromByteCount: Int64(environment.libraryRepository.storageSize()), countStyle: .file)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                summaryGrid
                settingsLink
                savedProteinsSection
                cachedStructuresSection
                notesSection
            }
            .padding(MYSpacing.md)
        }
        .navigationTitle("Library")
        .moleculeScreenBackground()
        .onAppear { environment.libraryRepository.refresh() }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            LibraryStatTile(symbol: "bookmark.fill", title: "Saved", value: "\(environment.libraryRepository.savedProteinAccessions.count)")
            LibraryStatTile(symbol: "note.text", title: "Notes", value: "\(environment.libraryRepository.notes.count)")
            LibraryStatTile(symbol: "internaldrive", title: "Cache", value: storageText)
        }
    }

    private var settingsLink: some View {
        NavigationLink {
            ProfileView(environment: environment)
        } label: {
            GlassCard {
                HStack(spacing: MYSpacing.md) {
                    MolecularLogo(size: 50)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profile & Settings")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Health access, privacy, appearance, cache, and reset controls")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var savedProteinsSection: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Saved Proteins", detail: "\(savedProteins.count)")
            if savedProteins.isEmpty {
                LibraryEmptyCard(symbol: "bookmark", title: "Library is empty", message: "Save proteins from their detail page to collect them here.")
            } else {
                LazyVStack(spacing: MYSpacing.sm) {
                    ForEach(savedProteins) { protein in
                        NavigationLink(value: AppRoute.protein(protein.uniprotAccession)) {
                            ProteinMiniRow(protein: protein)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var cachedStructuresSection: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Offline Cache", detail: downloadedAccessions.isEmpty ? nil : "\(downloadedAccessions.count) cached")
            GlassCard {
                VStack(alignment: .leading, spacing: MYSpacing.md) {
                    HStack(spacing: MYSpacing.md) {
                        Image(systemName: "internaldrive")
                            .foregroundStyle(Color.myAccent)
                            .frame(width: 42, height: 42)
                            .background(Color.myAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: MYRadius.sm, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cached structures")
                                .font(.headline)
                            Text(storageText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.myAccent)
                        }
                        Spacer(minLength: 0)
                    }

                    Text("Cached structures are AlphaFold 3D files saved on this device after you open the viewer. They make structures load faster and can help when the network is unavailable; clearing the cache does not remove saved proteins or notes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(role: .destructive) {
                        showingClearCacheConfirmation = true
                    } label: {
                        Label("Clear cached structures", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(downloadedAccessions.isEmpty)
                    .accessibilityIdentifier("Clear cached structures")
                }
            }
        }
        .confirmationDialog("Clear cached structures?", isPresented: $showingClearCacheConfirmation, titleVisibility: .visible) {
            Button("Clear cached structures", role: .destructive) {
                clearCachedStructures()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes locally cached AlphaFold structure files. Saved proteins and notes stay in your library.")
        }
    }

    private func clearCachedStructures() {
        try? environment.libraryRepository.clearCachedStructures()
        Task { try? await environment.structureCache.clear() }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Notes", detail: "\(environment.libraryRepository.notes.count)")
            NavigationLink {
                NotesView(environment: environment)
            } label: {
                GlassCard {
                    HStack(spacing: MYSpacing.md) {
                        Image(systemName: "note.text")
                            .foregroundStyle(Color.myAccent)
                            .frame(width: 42, height: 42)
                            .background(Color.myAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: MYRadius.sm, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(environment.libraryRepository.notes.isEmpty ? "Start a note" : "View all notes")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(environment.libraryRepository.notes.isEmpty ? "Capture study notes while reviewing proteins and systems." : "Search, review, and manage your saved study notes.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct NotesView: View {
    let environment: AppEnvironment
    @State private var query = ""
    @State private var noteText = ""

    private var filteredNotes: [UserNote] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return environment.libraryRepository.notes }
        return environment.libraryRepository.notes.filter { note in
            note.text.localizedCaseInsensitiveContains(trimmed)
                || note.itemID.localizedCaseInsensitiveContains(trimmed)
                || note.itemType.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                composer
                notesList
            }
            .padding(MYSpacing.md)
        }
        .navigationTitle("Notes")
        .searchable(text: $query, prompt: "Search notes")
        .moleculeScreenBackground()
        .onAppear { environment.libraryRepository.refresh() }
    }

    private var composer: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: MYSpacing.md) {
                TextField("Add an educational note", text: $noteText, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous))

                Button {
                    environment.libraryRepository.addNote(itemID: "general", itemType: "note", text: noteText)
                    noteText = ""
                } label: {
                    Label("Add Note", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var notesList: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "All Notes", detail: "\(filteredNotes.count)")
            if filteredNotes.isEmpty {
                LibraryEmptyCard(symbol: "note.text", title: query.isEmpty ? "No notes yet" : "No matching notes", message: query.isEmpty ? "Capture study notes while reviewing proteins and systems." : "Try searching for another phrase, topic, or protein accession.")
            } else {
                LazyVStack(spacing: MYSpacing.sm) {
                    ForEach(filteredNotes) { note in
                        LibraryNoteCard(note: note) {
                            environment.libraryRepository.deleteNote(note)
                        }
                    }
                }
            }
        }
    }
}

struct LibraryStatTile: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(Color.myAccent)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MYSpacing.md)
        .background(Color.myPanel, in: RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
    }
}

struct LibraryNoteCard: View {
    let note: UserNote
    let delete: () -> Void

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: MYSpacing.md) {
                Image(systemName: "note.text")
                    .foregroundStyle(Color.myAccent)
                    .frame(width: 38, height: 38)
                    .background(Color.myAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: MYRadius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(note.text)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(note.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button(role: .destructive, action: delete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete note")
            }
        }
    }
}

struct LibraryEmptyCard: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        GlassCard {
            HStack(spacing: MYSpacing.md) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.myAccent)
                    .frame(width: 42, height: 42)
                    .background(Color.myAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: MYRadius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview("Library") {
    NavigationStack { LibraryView(environment: .preview) }
}
