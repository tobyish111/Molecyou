import SwiftUI

struct ProfileView: View {
    let environment: AppEnvironment
    @AppStorage("demonstrationMode") private var demonstrationMode = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("appearance") private var appearance = "system"
    @State private var healthState: HealthAuthorizationState = .notRequested
    @State private var storageSize = 0

    var body: some View {
        List {
            Section {
                HStack(spacing: MYSpacing.md) {
                    MolecularLogo(size: 54)
                    VStack(alignment: .leading) {
                        Text("Toby")
                            .font(.title3.bold())
                        Text("The biology behind your health")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("HealthKit") {
                Label(label(for: healthState), systemImage: "heart.text.square")
                Button("Request or Manage Health Access") {
                    Task { healthState = await environment.healthProvider.requestAuthorization() }
                }
                Button("Open Settings") { openSettings() }
            }
            Section("Privacy") {
                NavigationLink("Privacy overview") { PrivacyOverviewView() }
                NavigationLink("Data-source attribution") { DataSourcesView() }
                Text("Raw HealthKit data stays on this device. Network requests are only made to public AlphaFold DB URLs for protein metadata and structures.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Preferences") {
                Toggle("Demonstration mode", isOn: $demonstrationMode)
                Picker("Appearance", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            }
            Section("Offline Storage") {
                HStack { Text("Structure cache"); Spacer(); Text(ByteCountFormatter.string(fromByteCount: Int64(storageSize), countStyle: .file)).foregroundStyle(.secondary) }
                Button(role: .destructive) {
                    try? environment.libraryRepository.clearCachedStructures()
                    Task { try? await environment.structureCache.clear(); storageSize = await environment.structureCache.size() }
                } label: { Label("Clear cached structures", systemImage: "trash") }
            }
            Section("About") {
                Text("Molecyou")
                Text("Version 1.0")
                Text(Disclaimer.text).font(.footnote).foregroundStyle(.secondary)
                Button(role: .destructive) {
                    demonstrationMode = true
                    hasCompletedOnboarding = false
                } label: { Label("Reset app", systemImage: "arrow.counterclockwise") }
            }
        }
        .navigationTitle("Profile")
        .task {
            healthState = await environment.healthProvider.authorizationState()
            storageSize = await environment.structureCache.size()
        }
    }

    private func label(for state: HealthAuthorizationState) -> String {
        switch state {
        case .unavailable: "HealthKit unavailable on this device"
        case .notRequested: "Health access not requested"
        case .requested: "Health access requested"
        case .available: "Health data available"
        case .failed(let message): "HealthKit error: \(message)"
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

struct PrivacyOverviewView: View {
    var body: some View {
        List {
            Label("Raw HealthKit measurements are not uploaded", systemImage: "icloud.slash")
            Label("HealthKit access is read-only", systemImage: "eye")
            Label("No advertising SDKs or third-party analytics", systemImage: "hand.raised")
            Label("Saved notes and downloaded structures stay local", systemImage: "internaldrive")
            Section("Medical limitation") { Text(Disclaimer.text) }
        }
        .navigationTitle("Privacy")
    }
}

struct DataSourcesView: View {
    var body: some View {
        List {
            Section("AlphaFold DB") {
                Text("Predicted structure metadata and mmCIF files are retrieved from the AlphaFold Protein Structure Database when a protein is opened or downloaded. AlphaFold DB data is licensed under CC BY 4.0.")
            }
            Section("UniProt") {
                Text("Bundled starter protein names, genes, and educational references use UniProt accessions for identification. Content is separated from application code for review.")
            }
        }
        .navigationTitle("Data Sources")
    }
}

#Preview("Profile") {
    NavigationStack { ProfileView(environment: .preview) }
}
