import SwiftUI

enum MYSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 34
}

enum MYRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 14
    static let lg: CGFloat = 22
    static let xl: CGFloat = 30
}

enum MYGradient {
    static let darkBackground = LinearGradient(colors: [Color(red: 0.01, green: 0.02, blue: 0.08), Color(red: 0.04, green: 0.05, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let oxygen = LinearGradient(colors: [Color(red: 1.0, green: 0.22, blue: 0.37), Color(red: 0.42, green: 0.18, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let recovery = LinearGradient(colors: [Color(red: 0.13, green: 0.27, blue: 0.73), Color(red: 0.04, green: 0.78, blue: 0.94)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let activity = LinearGradient(colors: [Color(red: 0.12, green: 0.64, blue: 0.37), Color(red: 0.13, green: 0.42, blue: 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let molecule = LinearGradient(colors: [.purple, .pink, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
    static let myInk = Color(red: 0.05, green: 0.07, blue: 0.12)
    static let myMuted = Color(red: 0.42, green: 0.46, blue: 0.55)
    static let myPanel = Color(.secondarySystemGroupedBackground)
    static let myBackground = Color(.systemGroupedBackground)
    static let myAccent = Color(red: 0.49, green: 0.31, blue: 1.0)
}

struct MolecularLogo: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill([Color.cyan, .purple, .pink, .blue, .mint][index])
                    .frame(width: size * 0.18, height: size * 0.18)
                    .offset(nodeOffset(index))
                    .shadow(color: [Color.cyan, .purple, .pink, .blue, .mint][index].opacity(0.55), radius: 6)
            }
            Path { path in
                let center = CGPoint(x: size / 2, y: size / 2)
                let points = (0..<5).map { CGPoint(x: center.x + nodeOffset($0).width, y: center.y + nodeOffset($0).height) }
                path.move(to: points[0])
                for point in points.dropFirst() { path.addLine(to: point) }
                path.addLine(to: points[1])
            }
            .stroke(Color.white.opacity(0.65), lineWidth: max(1.2, size * 0.035))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Molecyou logo")
    }

    private func nodeOffset(_ index: Int) -> CGSize {
        let r = size * 0.28
        let angle = Double(index) / 5.0 * .pi * 2.0 - .pi / 2.0
        return CGSize(width: cos(angle) * r, height: sin(angle) * r)
    }
}

struct SectionTitle: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = MYSpacing.md
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}

struct GradientIcon: View {
    let symbol: String
    let colors: [Color]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MYRadius.md, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}

struct RelevanceBadge: View {
    let relevance: RelevanceLevel

    var body: some View {
        Label(relevance.rawValue, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel("Relevance: \(relevance.rawValue)")
    }

    private var color: Color {
        switch relevance {
        case .high: .pink
        case .moderate: .orange
        case .general: .blue
        }
    }

    private var symbol: String {
        switch relevance {
        case .high: "flame"
        case .moderate: "circle.lefthalf.filled"
        case .general: "info.circle"
        }
    }
}

extension View {
    func moleculeScreenBackground() -> some View {
        background(MoleculePageBackground().ignoresSafeArea())
    }
}

struct MoleculePageBackground: View {
    var body: some View {
        ZStack {
            Color.myBackground
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.10),
                    Color.clear,
                    Color.pink.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            MoleculeBackgroundCanvas()
                .opacity(0.34)
        }
        .accessibilityHidden(true)
    }
}

private struct MoleculeBackgroundCanvas: View {
    var body: some View {
        Canvas { context, size in
            let points = [
                CGPoint(x: size.width * 0.12, y: size.height * 0.12),
                CGPoint(x: size.width * 0.34, y: size.height * 0.18),
                CGPoint(x: size.width * 0.74, y: size.height * 0.10),
                CGPoint(x: size.width * 0.88, y: size.height * 0.32),
                CGPoint(x: size.width * 0.18, y: size.height * 0.54),
                CGPoint(x: size.width * 0.48, y: size.height * 0.48),
                CGPoint(x: size.width * 0.78, y: size.height * 0.66),
                CGPoint(x: size.width * 0.28, y: size.height * 0.84),
                CGPoint(x: size.width * 0.62, y: size.height * 0.90)
            ]

            var path = Path()
            for index in points.indices.dropLast() {
                path.move(to: points[index])
                path.addLine(to: points[index + 1])
            }
            path.move(to: points[1])
            path.addLine(to: points[5])
            path.move(to: points[5])
            path.addLine(to: points[8])

            context.stroke(path, with: .color(Color.myAccent.opacity(0.12)), lineWidth: 1.2)

            let colors: [Color] = [.cyan, .purple, .pink, .mint, .blue]
            for (index, point) in points.enumerated() {
                let radius: CGFloat = index.isMultiple(of: 2) ? 3.8 : 2.8
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(colors[index % colors.count].opacity(0.22))
                )
            }
        }
    }
}

extension String {
    var colorsFromHex: [Color] {
        [Color(hex: self) ?? .myAccent]
    }
}

extension Color {
    nonisolated init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let value = Int(sanitized, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
