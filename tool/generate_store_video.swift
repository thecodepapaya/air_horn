import AppKit
import Accelerate
import AVFoundation
import CoreVideo

let canvasWidth = 1920
let canvasHeight = 1080
let framesPerSecond: Int32 = 30
let duration = 15.0

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let lightScreenshotURL = projectRoot.appendingPathComponent("docs/screenshots/home-light.png")
let darkScreenshotURL = projectRoot.appendingPathComponent("docs/screenshots/home-dark.png")
let drawerScreenshotURL = projectRoot.appendingPathComponent("docs/screenshots/drawer-dark.png")
let themeScreenshotURL = projectRoot.appendingPathComponent("docs/screenshots/theme-picker.png")
let iconURL = projectRoot.appendingPathComponent("assets/icon.png")
let outputDirectory = projectRoot.appendingPathComponent("docs/store-assets")
let outputURL = outputDirectory.appendingPathComponent("air-horn-promo.mp4")

try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)
try? FileManager.default.removeItem(at: outputURL)

guard
    let lightScreenshot = NSImage(contentsOf: lightScreenshotURL),
    let darkScreenshot = NSImage(contentsOf: darkScreenshotURL),
    let drawerScreenshot = NSImage(contentsOf: drawerScreenshotURL),
    let themeScreenshot = NSImage(contentsOf: themeScreenshotURL),
    let hornIcon = NSImage(contentsOf: iconURL)
else {
    fatalError("Missing screenshots or app icon. Capture the store screenshots first.")
}

func topRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
    NSRect(
        x: x,
        y: CGFloat(canvasHeight) - y - height,
        width: width,
        height: height
    )
}

func clamp(_ value: Double, _ lower: Double = 0, _ upper: Double = 1) -> Double {
    min(max(value, lower), upper)
}

func easeOut(_ value: Double) -> Double {
    1 - pow(1 - clamp(value), 3)
}

func sceneOpacity(time: Double, start: Double, end: Double, fade: Double = 0.45) -> CGFloat {
    let fadeIn = clamp((time - start) / fade)
    let fadeOut = clamp((end - time) / fade)
    return CGFloat(min(fadeIn, fadeOut))
}

func drawText(
    _ text: String,
    size: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    rect: NSRect,
    alignment: NSTextAlignment = .center,
    opacity: CGFloat = 1,
    tracking: CGFloat = 0
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color.withAlphaComponent(opacity),
        .paragraphStyle: paragraph,
        .kern: tracking,
    ]
    NSString(string: text).draw(in: rect, withAttributes: attributes)
}

func drawRoundedImage(
    _ image: NSImage,
    in rect: NSRect,
    radius: CGFloat,
    opacity: CGFloat
) {
    NSGraphicsContext.saveGraphicsState()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35 * opacity)
    shadow.shadowBlurRadius = 45
    shadow.shadowOffset = NSSize(width: 0, height: -16)
    shadow.set()
    NSColor.white.withAlphaComponent(opacity).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(
        in: rect,
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: opacity,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()
}

func drawFeature(
    _ text: String,
    x: CGFloat,
    top: CGFloat,
    width: CGFloat,
    color: NSColor,
    opacity: CGFloat
) {
    let rect = topRect(x: x, y: top, width: width, height: 86)
    color.withAlphaComponent(0.18 * opacity).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 43, yRadius: 43).fill()
    color.withAlphaComponent(opacity).setFill()
    NSBezierPath(ovalIn: topRect(x: x + 24, y: top + 26, width: 34, height: 34)).fill()
    drawText(
        text,
        size: 31,
        weight: .semibold,
        color: .white,
        rect: topRect(x: x + 78, y: top + 24, width: width - 110, height: 46),
        alignment: .left,
        opacity: opacity
    )
}

func drawFrame(at time: Double, in bitmap: NSBitmapImageRep) {
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        return
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let background = NSGradient(colors: [
        NSColor(calibratedRed: 0.055, green: 0.025, blue: 0.075, alpha: 1),
        NSColor(calibratedRed: 0.24, green: 0.035, blue: 0.095, alpha: 1),
        NSColor(calibratedRed: 0.035, green: 0.018, blue: 0.05, alpha: 1),
    ])!
    background.draw(
        in: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight),
        angle: -25
    )

    let glowX = CGFloat(380 + 1140 * (0.5 + 0.5 * sin(time * 0.55)))
    let glowRect = topRect(x: glowX - 380, y: 160, width: 760, height: 760)
    NSColor(calibratedRed: 1, green: 0.1, blue: 0.07, alpha: 0.12).setFill()
    NSBezierPath(ovalIn: glowRect).fill()

    let introOpacity = sceneOpacity(time: time, start: 0, end: 2.8)
    if introOpacity > 0 {
        let progress = easeOut((time - 0.05) / 0.9)
        let iconSize = CGFloat(330 + 42 * progress)
        let iconRect = topRect(
            x: 235 - CGFloat(16 * progress),
            y: 350 - CGFloat(12 * progress),
            width: iconSize,
            height: iconSize
        )
        NSColor(calibratedRed: 1, green: 0.12, blue: 0.08, alpha: introOpacity).setFill()
        NSBezierPath(ovalIn: iconRect.insetBy(dx: -34, dy: -34)).fill()
        hornIcon.draw(
            in: iconRect,
            from: NSRect(origin: .zero, size: hornIcon.size),
            operation: .sourceOver,
            fraction: introOpacity,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        drawText(
            "AIR HORN",
            size: 116,
            weight: .black,
            color: .white,
            rect: topRect(x: 730, y: 342, width: 1000, height: 150),
            alignment: .left,
            opacity: introOpacity,
            tracking: 8
        )
        drawText(
            "BIG SOUND. ONE BUTTON.",
            size: 46,
            weight: .medium,
            color: NSColor(calibratedWhite: 0.9, alpha: 1),
            rect: topRect(x: 738, y: 520, width: 900, height: 70),
            alignment: .left,
            opacity: introOpacity,
            tracking: 2
        )
        drawText(
            "A responsive pocket air horn for Android.",
            size: 32,
            weight: .regular,
            color: NSColor(calibratedWhite: 0.72, alpha: 1),
            rect: topRect(x: 740, y: 610, width: 860, height: 60),
            alignment: .left,
            opacity: introOpacity
        )
    }

    let homeOpacity = sceneOpacity(time: time, start: 2.4, end: 6.5)
    if homeOpacity > 0 {
        let progress = easeOut((time - 2.4) / 0.9)
        let width = CGFloat(500 + 24 * progress)
        let height = width * 16 / 9
        let screenshotRect = topRect(
            x: 170 - CGFloat(10 * progress),
            y: 72 - CGFloat(8 * progress),
            width: width,
            height: height
        )
        drawRoundedImage(lightScreenshot, in: screenshotRect, radius: 40, opacity: homeOpacity)
        drawText(
            "PRESS & HOLD",
            size: 78,
            weight: .black,
            color: .white,
            rect: topRect(x: 820, y: 280, width: 900, height: 100),
            alignment: .left,
            opacity: homeOpacity,
            tracking: 2
        )
        drawText(
            "Release to stop. It really is that simple.",
            size: 38,
            weight: .medium,
            color: NSColor(calibratedWhite: 0.85, alpha: 1),
            rect: topRect(x: 824, y: 405, width: 830, height: 70),
            alignment: .left,
            opacity: homeOpacity
        )
        drawFeature("CONTINUOUS HORN AUDIO", x: 820, top: 535, width: 650, color: .systemRed, opacity: homeOpacity)
        drawFeature("HAPTIC TAP FEEDBACK", x: 820, top: 645, width: 650, color: .systemPurple, opacity: homeOpacity)
        drawFeature("MUTE-AWARE VOLUME NUDGE", x: 820, top: 755, width: 650, color: .systemBlue, opacity: homeOpacity)
    }

    let themeOpacity = sceneOpacity(time: time, start: 6.1, end: 10.3)
    if themeOpacity > 0 {
        let progress = easeOut((time - 6.1) / 0.9)
        let width = CGFloat(465 + 20 * progress)
        let height = width * 16 / 9
        let darkRect = topRect(
            x: 95 - CGFloat(8 * progress),
            y: 100 - CGFloat(8 * progress),
            width: width,
            height: height
        )
        let themeRect = topRect(
            x: 575 + CGFloat(8 * progress),
            y: 100 - CGFloat(8 * progress),
            width: width,
            height: height
        )
        drawRoundedImage(darkScreenshot, in: darkRect, radius: 38, opacity: themeOpacity)
        drawRoundedImage(themeScreenshot, in: themeRect, radius: 38, opacity: themeOpacity)
        drawText(
            "LIGHT. DARK.\nYOURS.",
            size: 73,
            weight: .black,
            color: .white,
            rect: topRect(x: 1160, y: 285, width: 630, height: 190),
            alignment: .left,
            opacity: themeOpacity,
            tracking: 2
        )
        drawText(
            "Follow your system, or choose the look that works for you.",
            size: 34,
            weight: .medium,
            color: NSColor(calibratedWhite: 0.85, alpha: 1),
            rect: topRect(x: 1165, y: 520, width: 600, height: 120),
            alignment: .left,
            opacity: themeOpacity
        )
    }

    let featuresOpacity = sceneOpacity(time: time, start: 9.9, end: 12.8)
    if featuresOpacity > 0 {
        let width: CGFloat = 500
        let height = width * 16 / 9
        drawRoundedImage(
            drawerScreenshot,
            in: topRect(x: 170, y: 92, width: width, height: height),
            radius: 40,
            opacity: featuresOpacity
        )
        drawText(
            "EVERYTHING\nWITHIN REACH",
            size: 72,
            weight: .black,
            color: .white,
            rect: topRect(x: 820, y: 235, width: 850, height: 190),
            alignment: .left,
            opacity: featuresOpacity,
            tracking: 2
        )
        drawText(
            "Theme controls, rating, and app info live in one clean drawer.",
            size: 36,
            weight: .medium,
            color: NSColor(calibratedWhite: 0.85, alpha: 1),
            rect: topRect(x: 825, y: 500, width: 760, height: 120),
            alignment: .left,
            opacity: featuresOpacity
        )
        drawFeature("NO ACCOUNTS", x: 820, top: 670, width: 520, color: .systemRed, opacity: featuresOpacity)
        drawFeature("NO ADS", x: 820, top: 780, width: 520, color: .systemPurple, opacity: featuresOpacity)
    }

    let outroOpacity = sceneOpacity(time: time, start: 12.4, end: 15.1)
    if outroOpacity > 0 {
        let pulse = CGFloat(1 + 0.025 * sin(time * 5))
        let iconSize = 350 * pulse
        let iconRect = topRect(
            x: 300 - (iconSize - 350) / 2,
            y: 350 - (iconSize - 350) / 2,
            width: iconSize,
            height: iconSize
        )
        NSColor(calibratedRed: 1, green: 0.12, blue: 0.08, alpha: outroOpacity).setFill()
        NSBezierPath(ovalIn: iconRect.insetBy(dx: -34, dy: -34)).fill()
        hornIcon.draw(
            in: iconRect,
            from: NSRect(origin: .zero, size: hornIcon.size),
            operation: .sourceOver,
            fraction: outroOpacity,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        drawText(
            "READY WHEN YOU ARE",
            size: 74,
            weight: .black,
            color: .white,
            rect: topRect(x: 820, y: 365, width: 1040, height: 110),
            alignment: .left,
            opacity: outroOpacity,
            tracking: 2
        )
        drawText(
            "AIR HORN",
            size: 46,
            weight: .semibold,
            color: NSColor(calibratedRed: 1, green: 0.32, blue: 0.25, alpha: 1),
            rect: topRect(x: 825, y: 520, width: 780, height: 70),
            alignment: .left,
            opacity: outroOpacity,
            tracking: 5
        )
    }

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
}

let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
let input = AVAssetWriterInput(
    mediaType: .video,
    outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: canvasWidth,
        AVVideoHeightKey: canvasHeight,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 6_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        ],
    ]
)
input.expectsMediaDataInRealTime = false

let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: canvasWidth,
        kCVPixelBufferHeightKey as String: canvasHeight,
    ]
)

guard writer.canAdd(input) else {
    fatalError("Unable to add the video input.")
}
writer.add(input)

guard writer.startWriting() else {
    throw writer.error ?? NSError(domain: "AirHornVideo", code: 1)
}
writer.startSession(atSourceTime: .zero)

let totalFrames = Int(duration * Double(framesPerSecond))
for frameNumber in 0..<totalFrames {
    autoreleasepool {
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.002)
        }

        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: canvasWidth,
                pixelsHigh: canvasHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bitmapFormat: [.alphaFirst, .thirtyTwoBitLittleEndian],
                bytesPerRow: canvasWidth * 4,
                bitsPerPixel: 32
            ),
            let pool = adaptor.pixelBufferPool
        else {
            fatalError("Unable to allocate a frame buffer.")
        }

        drawFrame(
            at: Double(frameNumber) / Double(framesPerSecond),
            in: bitmap
        )

        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
              let pixelBuffer,
              let bitmapData = bitmap.bitmapData else {
            fatalError("Unable to create a video pixel buffer.")
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let destination = CVPixelBufferGetBaseAddress(pixelBuffer) {
            var sourceBuffer = vImage_Buffer(
                data: bitmapData,
                height: vImagePixelCount(canvasHeight),
                width: vImagePixelCount(canvasWidth),
                rowBytes: bitmap.bytesPerRow
            )
            var destinationBuffer = vImage_Buffer(
                data: destination,
                height: vImagePixelCount(canvasHeight),
                width: vImagePixelCount(canvasWidth),
                rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer)
            )
            var channelMap: [UInt8] = [3, 2, 1, 0]
            vImagePermuteChannels_ARGB8888(
                &sourceBuffer,
                &destinationBuffer,
                &channelMap,
                vImage_Flags(kvImageNoFlags)
            )
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let presentationTime = CMTime(
            value: Int64(frameNumber),
            timescale: framesPerSecond
        )
        guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            fatalError("Unable to append frame \(frameNumber): \(writer.error?.localizedDescription ?? "unknown error")")
        }
    }
}

input.markAsFinished()
let completion = DispatchSemaphore(value: 0)
writer.finishWriting {
    completion.signal()
}
completion.wait()

guard writer.status == .completed else {
    throw writer.error ?? NSError(domain: "AirHornVideo", code: 2)
}

print(outputURL.path)
