import SwiftUI
import UIKit

/// The printed background of a card face: a drawn pattern in the card's finish, or your own picture.
struct CardArt: View {
    let design: CardDesign
    let theme: CardTheme
    var imageData: Data? = nil

    var body: some View {
        // The gradient sets the size; everything else is layered on top so a photo can't stretch the card.
        theme.gradient
            .overlay { pattern }
            .overlay {
                if design != .photo {
                    // Soft sheen across the top, like light on card stock.
                    LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0)], startPoint: .top, endPoint: .center)
                }
            }
            .clipped()
    }

    @ViewBuilder
    private var pattern: some View {
        switch design {
        case .classic:
            EmptyView()
        case .metal:
            BrushedMetal()
        case .waves:
            Waves()
        case .geometric:
            Circles()
        case .lines:
            Engraving()
        case .glow:
            Glow(theme: theme)
        case .photo:
            if let image = imageData.flatMap(CardImageCache.image(for:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
    }
}

/// Fine horizontal grain with a band of reflected light, like a metal card.
private struct BrushedMetal: View {
    var body: some View {
        Canvas { context, size in
            var random = SeededRandom(seed: 42)
            var y: CGFloat = 0
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(.white.opacity(Double.random(in: 0.015...0.08, using: &random))), lineWidth: 0.7)
                y += CGFloat.random(in: 0.8...2.2, using: &random)
            }
        }
        .overlay {
            LinearGradient(stops: [
                .init(color: .white.opacity(0), location: 0.25),
                .init(color: .white.opacity(0.28), location: 0.45),
                .init(color: .white.opacity(0), location: 0.62),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Layered waves rolling along the bottom of the card.
private struct Waves: View {
    var body: some View {
        ZStack {
            WaveShape(baseline: 0.62, amplitude: 0.10, phase: 0).fill(.white.opacity(0.10))
            WaveShape(baseline: 0.72, amplitude: 0.08, phase: 1.8).fill(.white.opacity(0.08))
            WaveShape(baseline: 0.84, amplitude: 0.06, phase: 3.4).fill(.black.opacity(0.12))
            WaveShape(baseline: 0.52, amplitude: 0.12, phase: 0.9, isFilled: false).stroke(.white.opacity(0.2), lineWidth: 1)
        }
    }
}

private struct WaveShape: Shape {
    /// Where the wave sits, as a fraction of the height from the top.
    var baseline: CGFloat
    var amplitude: CGFloat
    var phase: CGFloat
    /// Filled waves close along the bottom edge; unfilled ones are just the line.
    var isFilled = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 48
        for step in 0...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(
                x: rect.minX + rect.width * progress,
                y: rect.minY + rect.height * (baseline + amplitude * sin(progress * .pi * 2.4 + phase))
            )
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        if isFilled {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// Large overlapping circles bleeding off the edges.
private struct Circles: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Circle().fill(.white.opacity(0.10))
                    .frame(width: width * 0.9, height: width * 0.9)
                    .position(x: width * 0.95, y: height * 0.05)
                Circle().fill(.white.opacity(0.07))
                    .frame(width: width * 0.65, height: width * 0.65)
                    .position(x: width * 0.78, y: height * 1.0)
                Circle().stroke(.white.opacity(0.16), lineWidth: max(1, width * 0.012))
                    .frame(width: width * 0.5, height: width * 0.5)
                    .position(x: width * 0.2, y: height * 1.05)
                Circle().fill(.black.opacity(0.10))
                    .frame(width: width * 0.42, height: width * 0.42)
                    .position(x: width * 1.02, y: height * 0.72)
            }
        }
    }
}

/// Fine engraved rings, like the security pattern on banknotes.
private struct Engraving: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.78, y: size.height * 0.5)
            let lineWidth = max(0.5, size.width / 500)
            for index in 0..<36 {
                let radius = size.width * (0.18 + CGFloat(index) * 0.018)
                let ellipse = Path(ellipseIn: CGRect(x: -radius, y: -radius * 0.55, width: radius * 2, height: radius * 1.1))
                    .applying(CGAffineTransform(rotationAngle: CGFloat(index) * .pi / 36)
                        .concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
                context.stroke(ellipse, with: .color(.white.opacity(0.07)), lineWidth: lineWidth)
            }
        }
    }
}

/// Soft blurred light, brightest in the top corner.
private struct Glow: View {
    let theme: CardTheme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Circle().fill(.white.opacity(0.35))
                    .frame(width: width * 0.55, height: width * 0.55)
                    .position(x: width * 0.85, y: height * 0.15)
                    .blur(radius: width * 0.12)
                Circle().fill(theme.colors[1].opacity(0.9))
                    .frame(width: width * 0.7, height: width * 0.7)
                    .position(x: width * 0.1, y: height * 0.95)
                    .blur(radius: width * 0.14)
                Circle().fill(.black.opacity(0.18))
                    .frame(width: width * 0.5, height: width * 0.5)
                    .position(x: width * 0.55, y: height * 1.1)
                    .blur(radius: width * 0.12)
            }
        }
    }
}

/// The EMV chip, with its gold contact pads.
struct CardChip: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                RoundedRectangle(cornerRadius: height * 0.2, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.93, green: 0.82, blue: 0.55), Color(red: 0.72, green: 0.58, blue: 0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Path { path in
                    for y in [height * 0.35, height * 0.65] {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width * 0.35, y: y))
                        path.move(to: CGPoint(x: width * 0.65, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    path.addRoundedRect(
                        in: CGRect(x: width * 0.35, y: height * 0.2, width: width * 0.3, height: height * 0.6),
                        cornerSize: CGSize(width: 3, height: 3)
                    )
                }
                .stroke(Color.black.opacity(0.25), lineWidth: 0.8)
            }
        }
        .frame(width: 40, height: 30)
    }
}

/// The network's name in the corner of the card.
struct NetworkMark: View {
    let network: CardNetwork

    var body: some View {
        switch network {
        case .visa:
            Text("VISA").font(.system(size: 22, weight: .heavy).italic())
        case .mastercard:
            Text("mastercard").font(.system(size: 15, weight: .bold))
        case .amex:
            Text("AMERICAN EXPRESS").font(.system(size: 9, weight: .heavy)).tracking(0.5)
        case .discover:
            Text("DISCOVER").font(.system(size: 13, weight: .heavy)).tracking(1)
        }
    }
}

/// Repeatable random numbers, so a texture looks the same every time it's drawn.
private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    // SplitMix64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

/// Decoded card pictures, so scrolling the Wallet doesn't decode the same JPEG over and over.
enum CardImageCache {
    private static let cache = NSCache<NSData, UIImage>()

    static func image(for data: Data) -> UIImage? {
        let key = data as NSData
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Shrinks a picked picture to card size and saves it as JPEG.
    static func prepare(_ image: UIImage, maxWidth: CGFloat = 1200) -> Data? {
        let scale = min(1, maxWidth / max(image.size.width, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(CardDesign.drawn) { design in
                CardArt(design: design, theme: .midnight)
                    .aspectRatio(1.586, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding()
    }
}
