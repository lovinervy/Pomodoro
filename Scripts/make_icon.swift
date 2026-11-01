import AppKit

// Рисует каваи-иконку Pomodoro: томатик с мордочкой на кремовом фоне.
// Запуск: swift Scripts/make_icon.swift <выходная_папка_iconset>
// Генерирует все размеры для .iconset.

let outDir = CommandLine.arguments[1]
let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let ctx = NSGraphicsContext.current!.cgContext
        let s = rect.width // условные единицы = пиксели этого размера

        // Фон: кремовый скруглённый квадрат (радиус ~22.4% по гайдлайну macOS)
        let inset = s * 0.02
        let bgRect = rect.insetBy(dx: inset, dy: inset)
        let bgPath = CGPath(roundedRect: bgRect, cornerWidth: s * 0.224, cornerHeight: s * 0.224, transform: nil)
        ctx.saveGState()
        ctx.addPath(bgPath)
        ctx.clip()
        ctx.setFillColor(CGColor(red: 1.0, green: 0.97, blue: 0.90, alpha: 1))
        ctx.fill(bgRect)

        // Мягкое свечение сверху
        let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.35),
                                       CGColor(red: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                              locations: [0, 0.5])!
        ctx.drawLinearGradient(glow, start: CGPoint(x: s/2, y: s), end: CGPoint(x: s/2, y: s*0.4), options: [])
        ctx.restoreGState()

        // Томат: круг с градиентом
        let tomatoD = s * 0.62
        let tomatoRect = CGRect(x: (s - tomatoD)/2, y: s * 0.16, width: tomatoD, height: tomatoD)
        ctx.saveGState()
        ctx.addEllipse(in: tomatoRect)
        ctx.clip()
        let tomatoGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [CGColor(red: 0.98, green: 0.52, blue: 0.47, alpha: 1),
                                             CGColor(red: 0.90, green: 0.33, blue: 0.30, alpha: 1)] as CFArray,
                                    locations: [0, 1])!
        ctx.drawRadialGradient(tomatoGrad,
                               startCenter: CGPoint(x: s/2, y: tomatoRect.midY + tomatoD*0.2), startRadius: 0,
                               endCenter: CGPoint(x: s/2, y: tomatoRect.midY), endRadius: tomatoD*0.7,
                               options: [])
        ctx.restoreGState()

        // Листик
        ctx.setFillColor(CGColor(red: 0.42, green: 0.72, blue: 0.42, alpha: 1))
        let leafW = s * 0.30, leafH = s * 0.13
        let leafRect = CGRect(x: (s - leafW)/2, y: tomatoRect.maxY - s*0.045, width: leafW, height: leafH)
        ctx.fillEllipse(in: leafRect)
        // Черешок
        ctx.setFillColor(CGColor(red: 0.36, green: 0.62, blue: 0.36, alpha: 1))
        ctx.fill(CGRect(x: s/2 - s*0.015, y: leafRect.maxY - s*0.02, width: s*0.03, height: s*0.07))

        // Мордочка
        let ink = CGColor(red: 0.30, green: 0.16, blue: 0.14, alpha: 1)
        ctx.setStrokeColor(ink)
        ctx.setFillColor(ink)
        ctx.setLineWidth(s * 0.022)
        ctx.setLineCap(.round)

        let faceY = tomatoRect.midY - s * 0.02
        let eyeDX = s * 0.11

        // Глаза — счастливые дужки
        for x in [s/2 - eyeDX, s/2 + eyeDX] {
            ctx.beginPath()
            ctx.addArc(center: CGPoint(x: x, y: faceY + s*0.02), radius: s*0.045,
                       startAngle: .pi * 1.15, endAngle: .pi * 1.85, clockwise: false)
            ctx.strokePath()
        }

        // Румянец
        ctx.setFillColor(CGColor(red: 1.0, green: 0.55, blue: 0.55, alpha: 0.55))
        for x in [s/2 - s*0.20, s/2 + s*0.20] {
            ctx.fillEllipse(in: CGRect(x: x - s*0.045, y: faceY - s*0.09, width: s*0.09, height: s*0.06))
        }

        // Улыбка — дужка вверх (∪)
        ctx.setStrokeColor(ink)
        ctx.beginPath()
        ctx.addArc(center: CGPoint(x: s/2, y: faceY - s*0.045), radius: s*0.055,
                   startAngle: .pi * 1.15, endAngle: .pi * 1.85, clockwise: false)
        ctx.strokePath()

        return true
    }
}

func savePNG(_ image: NSImage, size: Int, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return }
    rep.size = NSSize(width: size, height: size)
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
}

let base: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, px) in base {
    let img = drawIcon(size: CGFloat(px))
    savePNG(img, size: px, to: "\(outDir)/\(name).png")
}
print("iconset written to \(outDir)")
