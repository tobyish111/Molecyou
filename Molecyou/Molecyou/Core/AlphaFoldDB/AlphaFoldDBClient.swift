import Foundation

protocol AlphaFoldDBProviding: Sendable {
    func prediction(for accession: String) async throws -> AlphaFoldPrediction
    func downloadStructure(for prediction: AlphaFoldPrediction, format: StructureFormat) async throws -> URL
}

enum AlphaFoldError: LocalizedError, Equatable {
    case noPrediction(String)
    case missingStructureURL
    case invalidResponse
    case corruptDownload

    var errorDescription: String? {
        switch self {
        case .noPrediction(let accession): "No AlphaFold DB prediction was found for \(accession)."
        case .missingStructureURL: "This AlphaFold entry does not include the requested structure file."
        case .invalidResponse: "AlphaFold DB returned an unexpected response."
        case .corruptDownload: "The downloaded structure file could not be validated."
        }
    }
}

actor StructureCache {
    private let fileManager: FileManager
    private let directory: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "Structures", directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func cachedURL(accession: String, format: StructureFormat) -> URL? {
        let url = fileURL(accession: accession, format: format)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func store(data: Data, accession: String, format: StructureFormat) throws -> URL {
        guard data.count > 64 else { throw AlphaFoldError.corruptDownload }
        let url = fileURL(accession: accession, format: format)
        try data.write(to: url, options: [.atomic])
        return url
    }

    func clear() throws {
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func size() -> Int {
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return enumerator.compactMap { item -> Int? in
            guard let url = item as? URL else { return nil }
            return try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        }.reduce(0, +)
    }

    private func fileURL(accession: String, format: StructureFormat) -> URL {
        let ext = format == .mmcif ? "cif" : "bcif"
        return directory.appending(path: "AF-\(accession)-F1-model_v4.\(ext)")
    }
}

actor AlphaFoldDBClient: AlphaFoldDBProviding {
    private let session: URLSession
    private let structureCache: StructureCache
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared, structureCache: StructureCache) {
        self.session = session
        self.structureCache = structureCache
    }

    func prediction(for accession: String) async throws -> AlphaFoldPrediction {
        let url = URL(string: "https://alphafold.ebi.ac.uk/api/prediction/\(accession)")!
        let data = try await dataWithRetry(for: URLRequest(url: url, timeoutInterval: 20))
        let responses = try decoder.decode([AlphaFoldPredictionResponse].self, from: data)
        guard let response = responses.first else { throw AlphaFoldError.noPrediction(accession) }
        return response.domainModel
    }

    func downloadStructure(for prediction: AlphaFoldPrediction, format: StructureFormat) async throws -> URL {
        if let cached = await structureCache.cachedURL(accession: prediction.uniprotAccession, format: format) {
            return cached
        }

        let sourceURL: URL?
        switch format {
        case .mmcif: sourceURL = prediction.cifURL
        case .bcif: sourceURL = prediction.bcifURL
        }
        guard let sourceURL else { throw AlphaFoldError.missingStructureURL }
        let data = try await dataWithRetry(for: URLRequest(url: sourceURL, timeoutInterval: 45))
        return try await structureCache.store(data: data, accession: prediction.uniprotAccession, format: format)
    }

    private func dataWithRetry(for request: URLRequest) async throws -> Data {
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw AlphaFoldError.invalidResponse }
                if (200..<300).contains(http.statusCode) { return data }
                if [408, 429, 500, 502, 503, 504].contains(http.statusCode) {
                    throw URLError(.badServerResponse)
                }
                throw AlphaFoldError.invalidResponse
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                let delay = UInt64(pow(2.0, Double(attempt)) * 300_000_000)
                try await Task.sleep(nanoseconds: delay)
            }
        }
        throw lastError ?? AlphaFoldError.invalidResponse
    }
}

struct AlphaFoldPredictionResponse: Codable, Sendable {
    let entryId: String?
    let gene: String?
    let uniprotAccession: String?
    let organismScientificName: String?
    let latestVersion: Int?
    let cifUrl: URL?
    let bcifUrl: URL?
    let paeDocUrl: URL?
    let globalMetricValue: Double?

    nonisolated var domainModel: AlphaFoldPrediction {
        AlphaFoldPrediction(
            uniprotAccession: uniprotAccession ?? entryId?.replacingOccurrences(of: "AF-", with: "").components(separatedBy: "-").first ?? "Unknown",
            entryID: entryId ?? "Unknown",
            gene: gene,
            organismScientificName: organismScientificName,
            latestVersion: latestVersion,
            cifURL: cifUrl,
            bcifURL: bcifUrl,
            paeDocURL: paeDocUrl,
            confidenceAverage: globalMetricValue,
            license: "CC BY 4.0"
        )
    }
}

struct PreviewAlphaFoldDBClient: AlphaFoldDBProviding {
    func prediction(for accession: String) async throws -> AlphaFoldPrediction {
        AlphaFoldPrediction(
            uniprotAccession: accession,
            entryID: "AF-\(accession)-F1",
            gene: "HBB",
            organismScientificName: "Homo sapiens",
            latestVersion: 4,
            cifURL: Bundle.main.url(forResource: "sample_structure", withExtension: "cif"),
            bcifURL: nil,
            paeDocURL: nil,
            confidenceAverage: 93.4,
            license: "CC BY 4.0"
        )
    }

    func downloadStructure(for prediction: AlphaFoldPrediction, format: StructureFormat) async throws -> URL {
        if let url = Bundle.main.url(forResource: "sample_structure", withExtension: "cif") { return url }
        let url = FileManager.default.temporaryDirectory.appending(path: "sample_structure.cif")
        try "data_molecular_you_sample\n#\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
