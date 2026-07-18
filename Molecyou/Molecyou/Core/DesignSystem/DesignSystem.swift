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
        .accessibilityLabel("Molecular You logo")
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
        background(Color.myBackground.ignoresSafeArea())
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
