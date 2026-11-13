import SwiftUI

// ViePN Design System: adaptive surfaces, restrained indigo accents and reusable components.
enum LifeTheme {
    static let accent = Color(red: 0.40, green: 0.39, blue: 0.96)
    static let cyan = Color(red: 0.19, green: 0.78, blue: 0.92)
    static let ink = Color.primary
    static let muted = Color.secondary
    static let radius: CGFloat = 20
    static let horizontal: CGFloat = 20
}

struct LifePanel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: LifeTheme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: LifeTheme.radius).strokeBorder(.primary.opacity(0.055)))
    }
}

struct LifeHeading: View {
    let name: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.title3.bold())
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

struct LifeMetric: View {
    let title: String
    let count: Int
    let symbol: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol).foregroundStyle(tint).font(.title3)
            Text(count.formatted()).font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

struct LifeShortcut: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .padding(11)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct LifeBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            (scheme == .dark ? Color(red: 0.055, green: 0.074, blue: 0.14) : Color(red: 0.965, green: 0.968, blue: 0.99))
            RadialGradient(colors: [LifeTheme.accent.opacity(scheme == .dark ? 0.20 : 0.10), .clear], center: .topTrailing, startRadius: 15, endRadius: 450)
            RadialGradient(colors: [LifeTheme.cyan.opacity(0.06), .clear], center: .bottomLeading, startRadius: 10, endRadius: 350)
        }
        .ignoresSafeArea()
    }
}

struct LifeEmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: symbol).font(.system(size: 28)).foregroundStyle(LifeTheme.accent)
            Text(title).font(.headline)
            Text(detail).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
