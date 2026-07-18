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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MYRadius.xl, style: .continuous)
                .fill(MYGradient.darkBackground)
            HStack(spacing: MYSpacing.md) {
                BodySilhouette()
                    .frame(maxWidth: 230, maxHeight: 420)
                    .padding(.leading)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Body Atlas")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Select a physiological system to explore curated pathways and reference proteins.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                    ForEach(systems.prefix(6)) { system in
                        Label(system.name, systemImage: system.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, MYSpacing.lg)
                .padding(.trailing, MYSpacing.md)
            }
        }
        .frame(minHeight: 360)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Interactive body atlas with selectable biological systems")
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
