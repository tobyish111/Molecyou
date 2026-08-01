import SceneKit
import SwiftUI

struct NativeMolecularViewerView: UIViewRepresentable {
    let structureData: String
    let proteinName: String
    let representation: RepresentationType
    let colorMode: ColorMode
    let labelsEnabled: Bool
    let command: MolecularViewerCommand?
    let commandSequence: Int
    let onEvent: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = context.coordinator.scene
        context.coordinator.sceneView = view
        view.backgroundColor = UIColor(red: 2 / 255, green: 6 / 255, blue: 23 / 255, alpha: 1)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = false
        view.isJitteringEnabled = true
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        context.coordinator.configureScene()
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let renderKey = RenderKey(dataHash: structureData.hashValue, representation: representation, colorMode: colorMode, labelsEnabled: labelsEnabled)
        if context.coordinator.renderKey != renderKey {
            context.coordinator.renderKey = renderKey
            context.coordinator.render(structureData: structureData, proteinName: proteinName, representation: representation, colorMode: colorMode, labelsEnabled: labelsEnabled)
        }

        if context.coordinator.lastCommandSequence != commandSequence, let command {
            context.coordinator.lastCommandSequence = commandSequence
            context.coordinator.lastCommand = command
            context.coordinator.apply(command)
        }
    }

    final class Coordinator: NSObject {
        let scene = SCNScene()
        private let modelRoot = SCNNode()
        private let highlightRoot = SCNNode()
        private let cameraNode = SCNNode()
        private let cameraTarget = SCNNode()
        private let onEvent: @MainActor (String) -> Void
        weak var sceneView: SCNView?
        var renderKey: RenderKey?
        var lastCommand: MolecularViewerCommand?
        var lastCommandSequence = 0
        private var atoms: [MolecularAtom] = []
        private var backboneAtoms: [MolecularAtom] = []
        private var focusedRegion: FocusedMolecularRegion?
        private var currentProteinName = ""
        private var currentRepresentation: RepresentationType = .ribbon
        private var currentColorMode: ColorMode = .confidence
        private var currentLabelsEnabled = false
        private let normalizedSceneRadius: Float = 34
        private let canonicalCameraDistance: Float = 105

        init(onEvent: @escaping @MainActor (String) -> Void) {
            self.onEvent = onEvent
        }

        func configureScene() {
            guard scene.rootNode.childNodes.isEmpty else { return }
            scene.rootNode.addChildNode(modelRoot)
            modelRoot.addChildNode(highlightRoot)
            scene.rootNode.addChildNode(cameraTarget)
            scene.background.contents = UIColor(red: 2 / 255, green: 6 / 255, blue: 23 / 255, alpha: 1)
            scene.fogStartDistance = 80
            scene.fogEndDistance = 260
            scene.fogColor = UIColor(red: 2 / 255, green: 6 / 255, blue: 23 / 255, alpha: 1)

            let camera = SCNCamera()
            camera.fieldOfView = 42
            camera.zNear = 0.1
            camera.zFar = 10_000
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0, 120)
            let lookAt = SCNLookAtConstraint(target: cameraTarget)
            lookAt.isGimbalLockEnabled = true
            cameraNode.constraints = [lookAt]
            scene.rootNode.addChildNode(cameraNode)
            scene.rootNode.camera = camera

            let keyLight = SCNLight()
            keyLight.type = .area
            keyLight.intensity = 850
            keyLight.areaType = .rectangle
            keyLight.areaExtents = SIMD3<Float>(80, 80, 1)
            let keyLightNode = SCNNode()
            keyLightNode.light = keyLight
            keyLightNode.position = SCNVector3(80, 90, 120)
            scene.rootNode.addChildNode(keyLightNode)

            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = 520
            ambient.color = UIColor(red: 0.58, green: 0.72, blue: 1, alpha: 1)
            let ambientNode = SCNNode()
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            let fill = SCNLight()
            fill.type = .omni
            fill.intensity = 220
            fill.color = UIColor(red: 1.0, green: 0.36, blue: 0.72, alpha: 1)
            let fillNode = SCNNode()
            fillNode.light = fill
            fillNode.position = SCNVector3(-90, -70, 90)
            scene.rootNode.addChildNode(fillNode)
        }

        func render(structureData: String, proteinName: String, representation: RepresentationType, colorMode: ColorMode, labelsEnabled: Bool) {
            do {
                atoms = try MMCIFAtomParser.parse(structureData)
                backboneAtoms = atoms.filter { $0.atomName == "CA" }
                if backboneAtoms.count < 2 {
                    backboneAtoms = stride(from: 0, to: atoms.count, by: max(atoms.count / 600, 1)).map { atoms[$0] }
                }

                currentProteinName = proteinName
                currentRepresentation = representation
                currentColorMode = colorMode
                currentLabelsEnabled = labelsEnabled
                drawModel()
                normalizeModelScale()
                fitCamera(animated: false)
                Task { @MainActor in onEvent("Advanced native render · \(atoms.count) atoms") }
            } catch {
                Task { @MainActor in onEvent("failed: \(error.localizedDescription)") }
            }
        }

        func apply(_ command: MolecularViewerCommand) {
            switch command {
            case .resetCamera, .centerStructure:
                focusedRegion = nil
                drawModel()
                fitCamera(animated: true)
                Task { @MainActor in onEvent("Camera centered") }
            case .setRepresentation, .setColorMode, .toggleLabels:
                break
            case .focusResidue(let chainID, let sequenceNumber):
                focusResidue(chainID: chainID, sequenceNumber: sequenceNumber)
            case .focusRegion(let chainID, let startSequenceNumber, let endSequenceNumber, let label):
                focusRegion(chainID: chainID, startSequenceNumber: startSequenceNumber, endSequenceNumber: endSequenceNumber, label: label)
            }
        }

        private func drawModel() {
            modelRoot.childNodes.filter { $0 !== highlightRoot }.forEach { $0.removeFromParentNode() }
            if highlightRoot.parent == nil {
                modelRoot.addChildNode(highlightRoot)
            }
            highlightRoot.childNodes.forEach { $0.removeFromParentNode() }
            let renderAtoms = sampledAtoms(for: currentRepresentation)

            switch currentRepresentation {
            case .ribbon:
                renderTrace(backboneAtoms, radius: 0.28, colorMode: currentColorMode)
            case .surface:
                renderSpheres(backboneAtoms, radius: 1.15, colorMode: currentColorMode, opacity: 0.58)
                renderTrace(backboneAtoms, radius: 0.16, colorMode: currentColorMode)
            case .ballAndStick:
                renderSpheres(renderAtoms, radius: 0.38, colorMode: currentColorMode, opacity: 0.95)
                renderTrace(backboneAtoms, radius: 0.12, colorMode: currentColorMode)
            case .atoms:
                renderSpheres(renderAtoms, radius: 0.24, colorMode: currentColorMode, opacity: 0.9)
            }

            if currentLabelsEnabled {
                renderLabels(backboneAtoms, proteinName: currentProteinName)
            }

            if let focusedRegion {
                addHighlightMarkers(for: atoms.filter { focusedRegion.contains($0) })
            }
        }

        private func sampledAtoms(for representation: RepresentationType) -> [MolecularAtom] {
            let limit = representation == .atoms ? 2_000 : 1_200
            guard atoms.count > limit else { return atoms }
            let step = max(atoms.count / limit, 1)
            return stride(from: 0, to: atoms.count, by: step).map { atoms[$0] }
        }

        private func renderTrace(_ points: [MolecularAtom], radius: CGFloat, colorMode: ColorMode) {
            guard points.count > 1 else { return }
            for pair in zip(points, points.dropFirst()) where pair.0.chainID == pair.1.chainID {
                let style = visualStyle(for: pair.0, fallbackOpacity: 0.96, mode: colorMode)
                modelRoot.addChildNode(cylinder(from: pair.0.position, to: pair.1.position, radius: radius, color: style.color, opacity: style.opacity))
            }
            renderSpheres(points, radius: radius * 1.8, colorMode: colorMode, opacity: 0.98)
        }

        private func renderSpheres(_ atoms: [MolecularAtom], radius: CGFloat, colorMode: ColorMode, opacity: CGFloat) {
            for atom in atoms {
                let sphere = SCNSphere(radius: radius)
                sphere.segmentCount = 10
                let style = visualStyle(for: atom, fallbackOpacity: opacity, mode: colorMode)
                sphere.firstMaterial = material(color: style.color, opacity: style.opacity)
                let node = SCNNode(geometry: sphere)
                node.position = atom.position
                modelRoot.addChildNode(node)
            }
        }

        private func addHighlightMarkers(for atoms: [MolecularAtom]) {
            guard !atoms.isEmpty else { return }
            let backboneSelection = atoms.filter { $0.atomName == "CA" }
            let markerAtoms = backboneSelection.isEmpty ? atoms : backboneSelection
            let markerStep = max(markerAtoms.count / 18, 1)
            for atom in stride(from: 0, to: markerAtoms.count, by: markerStep).map({ markerAtoms[$0] }) {
                let sphere = SCNSphere(radius: 0.9)
                sphere.segmentCount = 16
                sphere.firstMaterial = material(color: UIColor(red: 0.19, green: 0.91, blue: 0.77, alpha: 1), opacity: 0.96)
                let node = SCNNode(geometry: sphere)
                node.position = atom.position
                highlightRoot.addChildNode(node)
            }
        }

        private func renderLabels(_ atoms: [MolecularAtom], proteinName: String) {
            for atom in atoms.prefix(12) {
                let text = SCNText(string: atom.sequenceNumber.map { "\(atom.chainID)\($0)" } ?? proteinName, extrusionDepth: 0.1)
                text.font = UIFont.systemFont(ofSize: 2.8, weight: .semibold)
                text.firstMaterial = material(color: .white, opacity: 0.92)
                let node = SCNNode(geometry: text)
                node.position = SCNVector3(atom.position.x + 1.2, atom.position.y + 1.2, atom.position.z)
                node.scale = SCNVector3(0.35, 0.35, 0.35)
                let constraint = SCNBillboardConstraint()
                constraint.freeAxes = .all
                node.constraints = [constraint]
                modelRoot.addChildNode(node)
            }
        }

        private func focusResidue(chainID: String, sequenceNumber: Int) {
            focusRegion(chainID: chainID, startSequenceNumber: sequenceNumber, endSequenceNumber: sequenceNumber, label: "Residue \(chainID)\(sequenceNumber)")
        }

        private func focusRegion(chainID: String, startSequenceNumber: Int, endSequenceNumber: Int, label: String) {
            let selectedAtoms = atoms.filter { atom in
                guard atom.chainID == chainID, let sequenceNumber = atom.sequenceNumber else { return false }
                return sequenceNumber >= startSequenceNumber && sequenceNumber <= endSequenceNumber
            }
            guard !selectedAtoms.isEmpty else { return }

            focusedRegion = FocusedMolecularRegion(chainID: chainID, startSequenceNumber: startSequenceNumber, endSequenceNumber: endSequenceNumber)
            drawModel()

            let center = centerPosition(for: selectedAtoms)
            let focus = modelRoot.convertPosition(center, to: nil)
            let scaledRadius = selectionRadius(for: selectedAtoms) * modelRoot.scale.x
            let cameraDistance = max(30, min(95, scaledRadius * 4.2 + 20))
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.38
            cameraTarget.position = focus
            cameraNode.position = SCNVector3(focus.x, focus.y, focus.z + cameraDistance)
            SCNTransaction.commit()
            sceneView?.pointOfView = cameraNode
            sceneView?.defaultCameraController.target = focus
            Task { @MainActor in onEvent("Focused \(label)") }
        }

        private func centerPosition(for atoms: [MolecularAtom]) -> SCNVector3 {
            let total = atoms.reduce(SCNVector3Zero) { partial, atom in
                SCNVector3(partial.x + atom.position.x, partial.y + atom.position.y, partial.z + atom.position.z)
            }
            let count = Float(max(atoms.count, 1))
            return SCNVector3(total.x / count, total.y / count, total.z / count)
        }

        private func selectionRadius(for atoms: [MolecularAtom]) -> Float {
            let center = centerPosition(for: atoms)
            return atoms.reduce(Float(1)) { radius, atom in
                let dx = atom.position.x - center.x
                let dy = atom.position.y - center.y
                let dz = atom.position.z - center.z
                return max(radius, sqrt(dx * dx + dy * dy + dz * dz))
            }
        }

        private func normalizeModelScale() {
            guard let bounds = atomBounds() else {
                modelRoot.position = SCNVector3Zero
                modelRoot.scale = SCNVector3(1, 1, 1)
                return
            }

            let center = SCNVector3((bounds.min.x + bounds.max.x) / 2, (bounds.min.y + bounds.max.y) / 2, (bounds.min.z + bounds.max.z) / 2)
            let dx = bounds.max.x - bounds.min.x
            let dy = bounds.max.y - bounds.min.y
            let dz = bounds.max.z - bounds.min.z
            let radius = max(1, sqrt(dx * dx + dy * dy + dz * dz) / 2)
            let scale = min(1.65, max(0.18, normalizedSceneRadius / radius))

            modelRoot.scale = SCNVector3(scale, scale, scale)
            modelRoot.position = SCNVector3(-center.x * scale, -center.y * scale, -center.z * scale)
        }

        private func fitCamera(animated: Bool) {
            let center = SCNVector3Zero
            let cameraPosition = SCNVector3(0, 0, canonicalCameraDistance)

            SCNTransaction.begin()
            SCNTransaction.animationDuration = animated ? 0.35 : 0
            cameraTarget.position = center
            cameraNode.position = cameraPosition
            SCNTransaction.commit()
            sceneView?.pointOfView = cameraNode
            sceneView?.defaultCameraController.target = center
        }

        private func atomBounds() -> (min: SCNVector3, max: SCNVector3)? {
            guard let first = atoms.first else { return nil }
            var minPoint = first.position
            var maxPoint = first.position

            for atom in atoms.dropFirst() {
                minPoint.x = min(minPoint.x, atom.position.x)
                minPoint.y = min(minPoint.y, atom.position.y)
                minPoint.z = min(minPoint.z, atom.position.z)
                maxPoint.x = max(maxPoint.x, atom.position.x)
                maxPoint.y = max(maxPoint.y, atom.position.y)
                maxPoint.z = max(maxPoint.z, atom.position.z)
            }

            return (minPoint, maxPoint)
        }

        private func cylinder(from start: SCNVector3, to end: SCNVector3, radius: CGFloat, color: UIColor, opacity: CGFloat) -> SCNNode {
            let startVector = SIMD3<Float>(start.x, start.y, start.z)
            let endVector = SIMD3<Float>(end.x, end.y, end.z)
            let direction = endVector - startVector
            let height = CGFloat(simd_length(direction))
            let cylinder = SCNCylinder(radius: radius, height: height)
            cylinder.radialSegmentCount = 8
            cylinder.firstMaterial = material(color: color, opacity: opacity)
            let node = SCNNode(geometry: cylinder)
            node.position = SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)
            if height > 0 {
                node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(direction))
            }
            return node
        }

        private func visualStyle(for atom: MolecularAtom, fallbackOpacity: CGFloat, mode: ColorMode) -> (color: UIColor, opacity: CGFloat) {
            guard let focusedRegion else {
                return (color(for: atom, mode: mode), fallbackOpacity)
            }

            if focusedRegion.contains(atom) {
                return (color(for: atom, mode: mode), max(fallbackOpacity, 0.96))
            }

            return (UIColor(red: 0.54, green: 0.57, blue: 0.64, alpha: 1), min(fallbackOpacity, 0.18))
        }

        private func material(color: UIColor, opacity: CGFloat) -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.emission.contents = color.withAlphaComponent(0.08)
            material.lightingModel = .physicallyBased
            material.roughness.contents = 0.42
            material.metalness.contents = 0.05
            material.transparency = opacity
            return material
        }

        private func color(for atom: MolecularAtom, mode: ColorMode) -> UIColor {
            switch mode {
            case .confidence:
                switch atom.confidence {
                case 90...: return UIColor(red: 0.18, green: 0.67, blue: 1, alpha: 1)
                case 70..<90: return UIColor(red: 0.25, green: 0.84, blue: 0.72, alpha: 1)
                case 50..<70: return UIColor(red: 0.96, green: 0.76, blue: 0.22, alpha: 1)
                default: return UIColor(red: 1, green: 0.28, blue: 0.33, alpha: 1)
                }
            case .chain:
                return chainPalette[abs(atom.chainID.hashValue) % chainPalette.count]
            case .element:
                return elementColor(atom.element)
            case .uniform:
                return UIColor(red: 0.68, green: 0.38, blue: 1, alpha: 1)
            }
        }

        private var chainPalette: [UIColor] {
            [
                UIColor(red: 0.54, green: 0.36, blue: 1, alpha: 1),
                UIColor(red: 1, green: 0.34, blue: 0.64, alpha: 1),
                UIColor(red: 0.13, green: 0.75, blue: 0.86, alpha: 1),
                UIColor(red: 0.28, green: 0.82, blue: 0.48, alpha: 1),
                UIColor(red: 1, green: 0.61, blue: 0.22, alpha: 1)
            ]
        }

        private func elementColor(_ element: String) -> UIColor {
            switch element.uppercased() {
            case "C": return UIColor(white: 0.78, alpha: 1)
            case "N": return UIColor(red: 0.31, green: 0.55, blue: 1, alpha: 1)
            case "O": return UIColor(red: 1, green: 0.25, blue: 0.32, alpha: 1)
            case "S": return UIColor(red: 1, green: 0.82, blue: 0.2, alpha: 1)
            case "FE": return UIColor(red: 0.88, green: 0.36, blue: 0.22, alpha: 1)
            default: return UIColor(red: 0.66, green: 0.86, blue: 1, alpha: 1)
            }
        }
    }
}

struct FocusedMolecularRegion: Equatable {
    let chainID: String
    let startSequenceNumber: Int
    let endSequenceNumber: Int

    func contains(_ atom: MolecularAtom) -> Bool {
        guard atom.chainID == chainID, let sequenceNumber = atom.sequenceNumber else { return false }
        return sequenceNumber >= startSequenceNumber && sequenceNumber <= endSequenceNumber
    }
}

struct RenderKey: Equatable {
    let dataHash: Int
    let representation: RepresentationType
    let colorMode: ColorMode
    let labelsEnabled: Bool
}

struct MolecularAtom: Sendable {
    let atomName: String
    let element: String
    let chainID: String
    let sequenceNumber: Int?
    let confidence: Float
    let position: SCNVector3
}

enum MMCIFAtomParser {
    enum ParserError: LocalizedError {
        case noAtoms

        var errorDescription: String? {
            "The AlphaFold mmCIF file did not contain readable atom coordinates."
        }
    }

    static func parse(_ text: String) throws -> [MolecularAtom] {
        var headers: [String] = []
        var atoms: [MolecularAtom] = []
        var readingAtomLoop = false

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }

            if line == "loop_" {
                headers.removeAll()
                readingAtomLoop = false
                continue
            }

            if line.hasPrefix("_atom_site.") {
                headers.append(String(line.split(separator: " ").first ?? Substring(line)))
                readingAtomLoop = true
                continue
            }

            if line.hasPrefix("_") {
                readingAtomLoop = false
                headers.removeAll()
                continue
            }

            if line == "#" {
                readingAtomLoop = false
                headers.removeAll()
                continue
            }

            guard readingAtomLoop, !headers.isEmpty else { continue }
            let values = tokenize(line)
            guard values.count >= headers.count, let atom = atom(from: values, headers: headers) else { continue }
            atoms.append(atom)
        }

        if atoms.isEmpty { throw ParserError.noAtoms }
        return atoms
    }

    private static func atom(from values: [String], headers: [String]) -> MolecularAtom? {
        func value(_ suffixes: [String]) -> String? {
            for suffix in suffixes {
                if let index = headers.firstIndex(where: { $0 == "_atom_site.\(suffix)" }), index < values.count {
                    let raw = values[index]
                    if raw != "." && raw != "?" { return raw }
                }
            }
            return nil
        }

        guard value(["group_PDB"]) == nil || value(["group_PDB"]) == "ATOM" || value(["group_PDB"]) == "HETATM" else { return nil }
        guard let x = Float(value(["Cartn_x"]) ?? ""), let y = Float(value(["Cartn_y"]) ?? ""), let z = Float(value(["Cartn_z"]) ?? "") else { return nil }

        let atomName = value(["label_atom_id", "auth_atom_id"]) ?? "?"
        let element = value(["type_symbol"]) ?? String(atomName.prefix(1))
        let chain = value(["label_asym_id", "auth_asym_id"]) ?? "A"
        let sequence = value(["label_seq_id", "auth_seq_id"]).flatMap(Int.init)
        let confidence = Float(value(["B_iso_or_equiv"]) ?? "0") ?? 0

        return MolecularAtom(atomName: atomName, element: element, chainID: chain, sequenceNumber: sequence, confidence: confidence, position: SCNVector3(x, y, z))
    }

    private static func tokenize(_ line: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?

        for character in line {
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }

            if character == "'" || character == "\"" {
                quote = character
                continue
            }

            if character.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current.removeAll()
                }
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
