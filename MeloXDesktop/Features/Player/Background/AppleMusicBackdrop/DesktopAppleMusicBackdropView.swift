import SwiftUI

/// macOS Music 1.6.6's `TSLBackdropMetalView` presentation reconstructed from
/// the app's model matrices, subdivided `CAMeshTransform` vertices, and AIR.
struct DesktopAppleMusicBackdropView: View {
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    let artworkURL: URL?
    let motionIntensity: Double
    let isActive: Bool

    @State private var clock = DesktopAppleMusicBackdropClock()
    @State private var pinchMesh =
        DesktopAppleMusicPinchMeshStore.randomMesh()

    var body: some View {
        GeometryReader { proxy in
            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 60.0,
                    paused: !isClockRunning
                )
            ) { context in
                let size = proxy.size
                let time = animationTime(at: context.date)

                ZStack {
                    Color(white: 0.30)

                    ZStack {
                        Color(white: 0.30)

                        transformedArtwork(
                            in: size,
                            time: time
                        )
                    }
                        .saturation(1.3)
                        .blur(
                            radius: blurSigma(for: size),
                            opaque: true
                        )
                        .layerEffect(
                            DesktopAppleMusicBackdropShader.pinch(
                                size: size,
                                time: time,
                                meshWarpTimeScale:
                                    meshWarpTimeScale(for: size.width),
                                blackScrimAlpha:
                                    scrimAlpha(for: size.width),
                                usesDarkAppearance:
                                    colorScheme == .dark,
                                averageLuminosity: 0.5,
                                meshPositions: pinchMesh.positions,
                                lookupOffsets: pinchMesh.lookupOffsets,
                                lookupTriangles:
                                    pinchMesh.lookupTriangles
                            ),
                            maxSampleOffset: size
                        )
                }
                .compositingGroup()
                .frame(width: size.width, height: size.height)
                .clipped()
            }
        }
        .onChange(of: isClockRunning, initial: true) { _, isRunning in
            clock.setRunning(isRunning, at: Date())
        }
    }

    @ViewBuilder
    private func transformedArtwork(
        in size: CGSize,
        time: TimeInterval
    ) -> some View {
        DesktopAppleMusicBackdropArtwork(artworkURL: artworkURL) { image in
            ZStack {
                transformedLayer(
                    image,
                    size: size,
                    translation: .zero,
                    basePeriod: 120,
                    time: time
                )

                transformedLayer(
                    image,
                    size: size,
                    translation: CGPoint(x: -0.5, y: -0.7),
                    basePeriod: 90,
                    time: time
                )

                transformedLayer(
                    image,
                    size: size,
                    translation: CGPoint(x: -0.95, y: 0.7),
                    basePeriod: 70,
                    time: time
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func transformedLayer(
        _ image: Image,
        size: CGSize,
        translation: CGPoint,
        basePeriod: TimeInterval,
        time: TimeInterval
    ) -> some View {
        let angle = cycleAngle(time: time, basePeriod: basePeriod)

        return image
            .resizable()
            .frame(width: size.width, height: size.width)
            .rotationEffect(angle)
            .offset(
                x: translation.x * size.width * 0.5,
                y: translation.y * size.width * 0.5
            )
            .rotationEffect(angle)
    }

    private func cycleAngle(
        time: TimeInterval,
        basePeriod: TimeInterval
    ) -> Angle {
        .radians(
            time
                * 2
                * .pi
                / (basePeriod * rendererSpeed)
        )
    }

    private var isClockRunning: Bool {
        isActive
            && scenePhase == .active
    }

    private func animationTime(at date: Date) -> TimeInterval {
        clock.elapsed(at: date)
    }

    private var rendererSpeed: TimeInterval {
        if accessibilityReduceMotion {
            return 5
        }
        return 0.5 / max(motionIntensity, 0.1)
    }

    private func scrimAlpha(for width: CGFloat) -> Double {
        let progress = min(max((width - 400) / 400, 0), 1)
        return 0.7 - 0.4 * Double(progress)
    }

    private func meshWarpTimeScale(for width: CGFloat) -> Double {
        let progress = min(max((width - 400) / 400, 0), 1)
        return min(max(10.5 - 9 * Double(progress), 0.1), 10)
    }

    private func blurSigma(for size: CGSize) -> CGFloat {
        let sigma = floor(hypot(size.width, size.height) * 0.045_394_707)
        return min(max(sigma, 4), 2_000)
    }
}
