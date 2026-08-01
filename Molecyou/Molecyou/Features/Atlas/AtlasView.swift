import SwiftUI

struct AtlasView: View {
    let environment: AppEnvironment
    @State private var selectedSystemID: String?

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                NavigationSplitView {
                    atlasList
                        .navigationTitle("Atlas")
                } detail: {
                    if let id = selectedSystemID, let system = environment.knowledgeGraph.system(id: id) {
                        SystemDetailView(environment: environment, system: system)
                    } else {
                        BodyAtlasHero(systems: environment.knowledgeGraph.systems)
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: MYSpacing.lg) {
                        BodyAtlasHero(systems: environment.knowledgeGraph.systems)
                        atlasList
                    }
                    .padding(MYSpacing.md)
                }
                .navigationTitle("Body Atlas")
                .moleculeScreenBackground()
            }
        }
    }

    private var atlasList: some View {
        List(selection: $selectedSystemID) {
            Section("Systems") {
                ForEach(environment.knowledgeGraph.systems) { system in
                    NavigationLink(value: AppRoute.system(system.id)) {
                        HStack(spacing: MYSpacing.md) {
                            GradientIcon(symbol: system.icon, colors: system.accentColors.compactMap(Color.init(hex:)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(system.name).font(.headline)
                                Text(system.shortDescription).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .tag(system.id)
                }
            }
        }
        .listStyle(.insetGrouped)
        .frame(minHeight: UIDevice.current.userInterfaceIdiom == .pad ? nil : 560)
    }
}

struct BodyAtlasHero: View {
    let systems: [BiologicalSystem]
    let selectedSystemID: String?
    let onSelectSystem: ((String) -> Void)?

    init(systems: [BiologicalSystem], selectedSystemID: String? = nil, onSelectSystem: ((String) -> Void)? = nil) {
        self.systems = systems
        self.selectedSystemID = selectedSystemID
        self.onSelectSystem = onSelectSystem
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MYRadius.xl, style: .continuous)
                .fill(MYGradient.darkBackground)
            LinearGradient(colors: [.cyan.opacity(0.28), .purple.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: MYRadius.xl, style: .continuous))
            AtlasMoleculeBackdrop()
                .opacity(0.32)
                .clipShape(RoundedRectangle(cornerRadius: MYRadius.xl, style: .continuous))
            VStack(alignment: .leading, spacing: MYSpacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Body Atlas")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Tap a process on the body to find its system card below.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, MYSpacing.lg)
                .padding(.top, MYSpacing.lg)

                AtlasBodyProcessMap(systems: systems, selectedSystemID: selectedSystemID) { systemID in
                    onSelectSystem?(systemID)
                }
                .frame(height: 360)
                .padding(.horizontal, MYSpacing.sm)
                .padding(.bottom, MYSpacing.md)
            }
        }
        .frame(minHeight: 360)
        .overlay {
            RoundedRectangle(cornerRadius: MYRadius.xl, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .cyan.opacity(0.16), radius: 24, x: 0, y: 12)
        .accessibilityElement(children: .contain)
    }
}

struct AtlasBodyProcessMap: View {
    let systems: [BiologicalSystem]
    let selectedSystemID: String?
    let onSelectSystem: (String) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AtlasBodyModel()
                    .frame(width: min(geometry.size.width * 0.72, 260), height: geometry.size.height * 0.96)
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5)

                ForEach(systems) { system in
                    let point = position(for: system, in: geometry.size)
                    AtlasBodyMarker(system: system, isSelected: selectedSystemID == system.id) {
                        onSelectSystem(system.id)
                    }
                    .position(point)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
    }

    private func position(for system: BiologicalSystem, in size: CGSize) -> CGPoint {
        let normalized: CGPoint
        switch system.id {
        case "sleep-circadian": normalized = CGPoint(x: 0.50, y: 0.13)
        case "nervous-system": normalized = CGPoint(x: 0.62, y: 0.22)
        case "respiratory-biology": normalized = CGPoint(x: 0.42, y: 0.34)
        case "oxygen-transport": normalized = CGPoint(x: 0.56, y: 0.38)
        case "cardiac-signaling": normalized = CGPoint(x: 0.47, y: 0.42)
        case "immune-defense": normalized = CGPoint(x: 0.35, y: 0.48)
        case "endocrine": normalized = CGPoint(x: 0.63, y: 0.52)
        case "cellular-energy": normalized = CGPoint(x: 0.44, y: 0.61)
        case "renal": normalized = CGPoint(x: 0.57, y: 0.68)
        default:
            switch system.kind {
            case .cardiovascular: normalized = CGPoint(x: 0.50, y: 0.40)
            case .respiratory: normalized = CGPoint(x: 0.45, y: 0.34)
            case .musculoskeletal: normalized = CGPoint(x: 0.31, y: 0.63)
            case .nervous: normalized = CGPoint(x: 0.56, y: 0.23)
            case .endocrine: normalized = CGPoint(x: 0.60, y: 0.52)
            case .immune: normalized = CGPoint(x: 0.36, y: 0.48)
            case .digestive, .metabolic: normalized = CGPoint(x: 0.45, y: 0.61)
            case .renal: normalized = CGPoint(x: 0.57, y: 0.68)
            case .circadian: normalized = CGPoint(x: 0.50, y: 0.13)
            }
        }
        return CGPoint(x: size.width * normalized.x, y: size.height * normalized.y)
    }
}

struct AtlasBodyMarker: View {
    let system: BiologicalSystem
    let isSelected: Bool
    let action: () -> Void

    private var colors: [Color] {
        let systemColors = system.accentColors.compactMap(Color.init(hex:))
        return systemColors.isEmpty ? [.cyan, .purple] : systemColors
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: system.icon)
                    .font(.caption.weight(.bold))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.16), in: Circle())
                if isSelected {
                    Text(system.name)
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .leading)))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, isSelected ? 9 : 5)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.82))
                    .overlay {
                        Capsule(style: .continuous)
                            .fill(LinearGradient(colors: colors.map { $0.opacity(isSelected ? 0.46 : 0.30) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(isSelected ? .white.opacity(0.84) : .white.opacity(0.24), lineWidth: isSelected ? 1.5 : 1)
                    }
            }
            .shadow(color: (colors.first ?? .cyan).opacity(isSelected ? 0.34 : 0.18), radius: isSelected ? 14 : 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isSelected)
        .accessibilityLabel(system.name)
    }
}

struct AtlasBodyModel: View {
    var body: some View {
        Canvas { context, size in
            let glowRect = CGRect(x: size.width * 0.18, y: size.height * 0.06, width: size.width * 0.64, height: size.height * 0.86)
            context.fill(Path(ellipseIn: glowRect), with: .radialGradient(Gradient(colors: [.cyan.opacity(0.20), .purple.opacity(0.06), .clear]), center: CGPoint(x: size.width * 0.5, y: size.height * 0.45), startRadius: 10, endRadius: size.width * 0.42))

            let head = CGRect(x: size.width * 0.42, y: size.height * 0.04, width: size.width * 0.16, height: size.width * 0.18)
            context.fill(Path(ellipseIn: head), with: .linearGradient(Gradient(colors: [.white.opacity(0.70), .cyan.opacity(0.24)]), startPoint: head.origin, endPoint: CGPoint(x: head.maxX, y: head.maxY)))
            context.stroke(Path(ellipseIn: head), with: .color(.white.opacity(0.34)), lineWidth: 1)

            var torso = Path()
            torso.move(to: CGPoint(x: size.width * 0.50, y: size.height * 0.20))
            torso.addCurve(to: CGPoint(x: size.width * 0.32, y: size.height * 0.50), control1: CGPoint(x: size.width * 0.36, y: size.height * 0.22), control2: CGPoint(x: size.width * 0.28, y: size.height * 0.38))
            torso.addCurve(to: CGPoint(x: size.width * 0.42, y: size.height * 0.78), control1: CGPoint(x: size.width * 0.34, y: size.height * 0.64), control2: CGPoint(x: size.width * 0.37, y: size.height * 0.72))
            torso.addCurve(to: CGPoint(x: size.width * 0.58, y: size.height * 0.78), control1: CGPoint(x: size.width * 0.47, y: size.height * 0.84), control2: CGPoint(x: size.width * 0.53, y: size.height * 0.84))
            torso.addCurve(to: CGPoint(x: size.width * 0.68, y: size.height * 0.50), control1: CGPoint(x: size.width * 0.63, y: size.height * 0.72), control2: CGPoint(x: size.width * 0.66, y: size.height * 0.64))
            torso.addCurve(to: CGPoint(x: size.width * 0.50, y: size.height * 0.20), control1: CGPoint(x: size.width * 0.72, y: size.height * 0.38), control2: CGPoint(x: size.width * 0.64, y: size.height * 0.22))
            context.fill(torso, with: .linearGradient(Gradient(colors: [.white.opacity(0.58), .cyan.opacity(0.20), .purple.opacity(0.18)]), startPoint: CGPoint(x: size.width * 0.34, y: size.height * 0.20), endPoint: CGPoint(x: size.width * 0.70, y: size.height * 0.80)))
            context.stroke(torso, with: .linearGradient(Gradient(colors: [.white.opacity(0.50), .cyan.opacity(0.52), .purple.opacity(0.42)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), lineWidth: 2)

            drawLimb(from: CGPoint(x: size.width * 0.35, y: size.height * 0.36), to: CGPoint(x: size.width * 0.16, y: size.height * 0.70), in: &context)
            drawLimb(from: CGPoint(x: size.width * 0.65, y: size.height * 0.36), to: CGPoint(x: size.width * 0.84, y: size.height * 0.70), in: &context)
            drawLimb(from: CGPoint(x: size.width * 0.45, y: size.height * 0.76), to: CGPoint(x: size.width * 0.36, y: size.height * 0.98), in: &context)
            drawLimb(from: CGPoint(x: size.width * 0.55, y: size.height * 0.76), to: CGPoint(x: size.width * 0.64, y: size.height * 0.98), in: &context)

            drawOrgan(ellipse: CGRect(x: size.width * 0.39, y: size.height * 0.29, width: size.width * 0.10, height: size.height * 0.16), color: .cyan, in: &context)
            drawOrgan(ellipse: CGRect(x: size.width * 0.51, y: size.height * 0.29, width: size.width * 0.10, height: size.height * 0.16), color: .cyan, in: &context)
            drawOrgan(ellipse: CGRect(x: size.width * 0.45, y: size.height * 0.38, width: size.width * 0.12, height: size.height * 0.10), color: .pink, in: &context)
            drawOrgan(ellipse: CGRect(x: size.width * 0.42, y: size.height * 0.59, width: size.width * 0.07, height: size.height * 0.10), color: .blue, in: &context)
            drawOrgan(ellipse: CGRect(x: size.width * 0.51, y: size.height * 0.59, width: size.width * 0.07, height: size.height * 0.10), color: .blue, in: &context)
        }
    }

    private func drawLimb(from start: CGPoint, to end: CGPoint, in context: inout GraphicsContext) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .linearGradient(Gradient(colors: [.white.opacity(0.48), .cyan.opacity(0.18)]), startPoint: start, endPoint: end), style: StrokeStyle(lineWidth: 16, lineCap: .round))
        context.stroke(path, with: .color(.white.opacity(0.16)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func drawOrgan(ellipse: CGRect, color: Color, in context: inout GraphicsContext) {
        context.fill(Path(ellipseIn: ellipse), with: .color(color.opacity(0.28)))
        context.stroke(Path(ellipseIn: ellipse), with: .color(.white.opacity(0.22)), lineWidth: 1)
    }
}

struct AtlasSystemChip: View {
    let system: BiologicalSystem
    let isSelected: Bool
    let action: () -> Void

    private var colors: [Color] {
        let systemColors = system.accentColors.compactMap(Color.init(hex:))
        return systemColors.isEmpty ? [.cyan, .purple] : systemColors
    }

    var body: some View {
        Button(action: action) {
            Label {
                Text(system.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            } icon: {
                Image(systemName: system.icon)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous)
                    .fill(isSelected ? colors.first?.opacity(0.32) ?? .white.opacity(0.18) : .white.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous)
                            .stroke(isSelected ? .white.opacity(0.62) : .white.opacity(0.12), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(system.name)
    }
}

struct AtlasMoleculeBackdrop: View {
    var body: some View {
        Canvas { context, size in
            let points = [
                CGPoint(x: size.width * 0.12, y: size.height * 0.22),
                CGPoint(x: size.width * 0.32, y: size.height * 0.16),
                CGPoint(x: size.width * 0.54, y: size.height * 0.28),
                CGPoint(x: size.width * 0.78, y: size.height * 0.18),
                CGPoint(x: size.width * 0.88, y: size.height * 0.46),
                CGPoint(x: size.width * 0.66, y: size.height * 0.68),
                CGPoint(x: size.width * 0.38, y: size.height * 0.78),
                CGPoint(x: size.width * 0.16, y: size.height * 0.58)
            ]
            var path = Path()
            for index in points.indices {
                let point = points[index]
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
                context.fill(Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)), with: .color(.white.opacity(0.42)))
            }
            context.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 1)
        }
    }
}

struct BodySilhouette: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.18)
            context.stroke(Path(ellipseIn: CGRect(x: center.x - 26, y: center.y - 26, width: 52, height: 52)), with: .color(.cyan.opacity(0.75)), lineWidth: 2)
            var torso = Path()
            torso.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.27))
            torso.addCurve(to: CGPoint(x: size.width * 0.36, y: size.height * 0.62), control1: CGPoint(x: size.width * 0.31, y: size.height * 0.33), control2: CGPoint(x: size.width * 0.34, y: size.height * 0.5))
            torso.addCurve(to: CGPoint(x: size.width * 0.5, y: size.height * 0.86), control1: CGPoint(x: size.width * 0.38, y: size.height * 0.74), control2: CGPoint(x: size.width * 0.44, y: size.height * 0.8))
            torso.addCurve(to: CGPoint(x: size.width * 0.64, y: size.height * 0.62), control1: CGPoint(x: size.width * 0.56, y: size.height * 0.8), control2: CGPoint(x: size.width * 0.62, y: size.height * 0.74))
            torso.addCurve(to: CGPoint(x: size.width * 0.5, y: size.height * 0.27), control1: CGPoint(x: size.width * 0.66, y: size.height * 0.5), control2: CGPoint(x: size.width * 0.69, y: size.height * 0.33))
            context.stroke(torso, with: .linearGradient(Gradient(colors: [.cyan, .pink, .blue]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), lineWidth: 4)
            for y in stride(from: size.height * 0.34, through: size.height * 0.75, by: 34) {
                var rib = Path()
                rib.move(to: CGPoint(x: size.width * 0.38, y: y))
                rib.addQuadCurve(to: CGPoint(x: size.width * 0.62, y: y), control: CGPoint(x: size.width * 0.5, y: y + 18))
                context.stroke(rib, with: .color(.white.opacity(0.18)), lineWidth: 1.5)
            }
            context.fill(Path(ellipseIn: CGRect(x: size.width * 0.43, y: size.height * 0.36, width: 40, height: 56)), with: .color(.pink.opacity(0.55)))
        }
    }
}

#Preview("Atlas") {
    NavigationStack { AtlasView(environment: .preview) }
}
