import SwiftUI

/// Настроение мордочки по фазе цикла.
enum KawaiiMood {
    case focus      // сосредоточенная
    case happy      // довольная (перерыв)
    case sleepy     // сонная (длинный перерыв)
}

/// Минималистичная каваи-мордочка, целиком векторная (Canvas) —
/// чёткая на Retina и ничего не весит.
struct KawaiiFace: View {
    let mood: KawaiiMood
    var tint: Color = Color(red: 0.35, green: 0.25, blue: 0.25)

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let eyeY = h * 0.38
            let eyeDX = w * 0.20
            let midX = w / 2

            // Глаза
            switch mood {
            case .focus:
                // Открытые круглые глаза
                for x in [midX - eyeDX, midX + eyeDX] {
                    let r = w * 0.075
                    let rect = CGRect(x: x - r, y: eyeY - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(tint))
                }
            case .happy, .sleepy:
                // Счастливые дужки ^ ^
                for x in [midX - eyeDX, midX + eyeDX] {
                    var p = Path()
                    let r = w * 0.11
                    p.addArc(center: CGPoint(x: x, y: eyeY + r * 0.4), radius: r,
                             startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                    ctx.stroke(p, with: .color(tint), lineWidth: w * 0.055)
                }
            }

            // Румянец
            let blushColor = Color(red: 0.98, green: 0.65, blue: 0.65).opacity(mood == .focus ? 0.5 : 0.75)
            for x in [midX - w * 0.34, midX + w * 0.34] {
                let rect = CGRect(x: x - w * 0.09, y: h * 0.52, width: w * 0.18, height: h * 0.12)
                ctx.fill(Path(ellipseIn: rect), with: .color(blushColor))
            }

            // Рот
            var mouth = Path()
            switch mood {
            case .focus:
                // Маленькая аккуратная улыбка
                mouth.addArc(center: CGPoint(x: midX, y: h * 0.52), radius: w * 0.10,
                             startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            case .happy:
                // Широкая улыбка
                mouth.addArc(center: CGPoint(x: midX, y: h * 0.50), radius: w * 0.16,
                             startAngle: .degrees(15), endAngle: .degrees(165), clockwise: false)
            case .sleepy:
                // Сонное «о»
                let r = w * 0.08
                mouth = Path(ellipseIn: CGRect(x: midX - r, y: h * 0.55, width: r * 2, height: r * 1.6))
                ctx.fill(mouth, with: .color(tint))
                return
            }
            ctx.stroke(mouth, with: .color(tint),
                       style: StrokeStyle(lineWidth: w * 0.055, lineCap: .round))
        }
    }
}
