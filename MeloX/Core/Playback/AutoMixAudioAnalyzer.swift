@preconcurrency import AVFoundation
import CoreML
import Foundation

nonisolated struct AutoMixAnalysisRequest: Sendable {
    let songID: Int
    let source: PlaybackSource
    let duration: TimeInterval
    let isDownloaded: Bool
}

nonisolated struct AutoMixTrackAnalysis: Sendable {
    let bpm: Double
    let confidence: Double
    let beats: [TimeInterval]
    let downbeats: [TimeInterval]
    let regionStart: TimeInterval
    let normalizedEnergy: [Float]

    func energy(at absoluteTime: TimeInterval) -> Float {
        let relativeTime = absoluteTime - regionStart
        let frame = Int(
            (relativeTime * 50).rounded()
        )
        guard normalizedEnergy.indices.contains(frame) else {
            return 0
        }
        return normalizedEnergy[frame]
    }
}

nonisolated struct AutoMixPairAnalysis: Sendable {
    let outgoing: AutoMixTrackAnalysis
    let incoming: AutoMixTrackAnalysis
}

nonisolated enum AutoMixAnalysisError: LocalizedError {
    case modelMissing
    case audioTrackMissing
    case readerCouldNotStart
    case readerFailed(Error?)
    case invalidAudioBuffer
    case invalidModelOutput

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            "BeatNet Core ML 模型未包含在应用中。"
        case .audioTrackMissing:
            "歌曲没有可分析的音频轨道。"
        case .readerCouldNotStart:
            "无法启动歌曲分析。"
        case .readerFailed(let error):
            error?.localizedDescription ?? "读取歌曲音频失败。"
        case .invalidAudioBuffer:
            "歌曲解码结果无法用于分析。"
        case .invalidModelOutput:
            "BeatNet 返回了无效结果。"
        }
    }
}

actor AutoMixAudioAnalyzer {
    private enum Region: Hashable {
        case head
        case tail(durationMilliseconds: Int)
    }

    private struct CacheKey: Hashable {
        let songID: Int
        let region: Region
    }

    private var cachedAnalyses: [CacheKey: AutoMixTrackAnalysis] = [:]
    private var model: MLModel?
    private let featureExtractor: BeatNetFeatureExtractor

    init() {
        featureExtractor = try! BeatNetFeatureExtractor()
    }

    func analyzePair(
        outgoing: AutoMixAnalysisRequest,
        incoming: AutoMixAnalysisRequest
    ) async throws -> AutoMixPairAnalysis {
        let outgoingAnalysis = try await analyze(
            outgoing,
            region: .tail(
                durationMilliseconds: Int(
                    (outgoing.duration * 1_000).rounded()
                )
            )
        )
        try Task.checkCancellation()
        let incomingAnalysis = try await analyze(
            incoming,
            region: .head
        )
        return AutoMixPairAnalysis(
            outgoing: outgoingAnalysis,
            incoming: incomingAnalysis
        )
    }

    func clearCache() {
        cachedAnalyses.removeAll()
    }

    private func analyze(
        _ request: AutoMixAnalysisRequest,
        region: Region
    ) async throws -> AutoMixTrackAnalysis {
        let cacheKey = CacheKey(
            songID: request.songID,
            region: region
        )
        if let cached = cachedAnalyses[cacheKey] {
            return cached
        }

        let regionStart: TimeInterval
        switch region {
        case .head:
            regionStart = 0
        case .tail:
            regionStart = max(
                request.duration
                    - BeatNetFeatureExtractor.windowDuration,
                0
            )
        }
        let samples = try await decodeSamples(
            from: request.source.url,
            startTime: regionStart,
            duration: min(
                BeatNetFeatureExtractor.windowDuration,
                max(request.duration - regionStart, 0)
            )
        )
        try Task.checkCancellation()
        let features = featureExtractor.extract(from: samples)
        let activations = try predict(features.values)
        let analysis = BeatNetTemporalDecoder.decode(
            activations: activations,
            energy: features.normalizedEnergy,
            regionStart: regionStart
        )
        cachedAnalyses[cacheKey] = analysis
        return analysis
    }

    private func loadModel() throws -> MLModel {
        if let model {
            return model
        }
        guard let modelURL = Bundle.main.url(
            forResource: "BeatNetBDA",
            withExtension: "mlmodelc"
        ) else {
            throw AutoMixAnalysisError.modelMissing
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        let loadedModel = try MLModel(
            contentsOf: modelURL,
            configuration: configuration
        )
        model = loadedModel
        return loadedModel
    }

    private func predict(
        _ features: [Float]
    ) throws -> [(beat: Float, downbeat: Float)] {
        let expectedCount =
            BeatNetFeatureExtractor.frameCount
                * BeatNetFeatureExtractor.featureCount
        guard features.count == expectedCount else {
            throw AutoMixAnalysisError.invalidModelOutput
        }
        let input = try MLMultiArray(
            shape: [
                1,
                NSNumber(value: BeatNetFeatureExtractor.frameCount),
                NSNumber(value: BeatNetFeatureExtractor.featureCount),
            ],
            dataType: .float32
        )
        let inputPointer = input.dataPointer.bindMemory(
            to: Float.self,
            capacity: expectedCount
        )
        features.withUnsafeBufferPointer { featuresPointer in
            guard let baseAddress = featuresPointer.baseAddress else {
                return
            }
            inputPointer.update(
                from: baseAddress,
                count: expectedCount
            )
        }
        let provider = try MLDictionaryFeatureProvider(
            dictionary: ["features": input]
        )
        let prediction = try loadModel().prediction(from: provider)
        guard let output = prediction.featureValue(
            for: "activations"
        )?.multiArrayValue,
              output.shape.count == 3 else {
            throw AutoMixAnalysisError.invalidModelOutput
        }
        var activations: [(Float, Float)] = []
        activations.reserveCapacity(
            BeatNetFeatureExtractor.frameCount
        )
        for frame in 0..<BeatNetFeatureExtractor.frameCount {
            let beat = output[
                [
                    0,
                    NSNumber(value: frame),
                    0,
                ]
            ].floatValue
            let downbeat = output[
                [
                    0,
                    NSNumber(value: frame),
                    1,
                ]
            ].floatValue
            activations.append((beat, downbeat))
        }
        return activations
    }

    private func decodeSamples(
        from url: URL,
        startTime: TimeInterval,
        duration: TimeInterval
    ) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(
            withMediaType: .audio
        )
        guard let track = tracks.first else {
            throw AutoMixAnalysisError.audioTrackMissing
        }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(
                seconds: max(startTime, 0),
                preferredTimescale: 600
            ),
            duration: CMTime(
                seconds: max(duration, 0.1),
                preferredTimescale: 600
            )
        )
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey:
                    Double(BeatNetFeatureExtractor.sampleRate),
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw AutoMixAnalysisError.invalidAudioBuffer
        }
        reader.add(output)
        guard reader.startReading() else {
            throw AutoMixAnalysisError.readerCouldNotStart
        }

        let maximumSampleCount =
            BeatNetFeatureExtractor.sampleRate
                * Int(BeatNetFeatureExtractor.windowDuration)
        var samples: [Float] = []
        samples.reserveCapacity(maximumSampleCount)
        while reader.status == .reading,
              samples.count < maximumSampleCount {
            try Task.checkCancellation()
            guard let sampleBuffer =
                output.copyNextSampleBuffer() else {
                break
            }
            defer {
                CMSampleBufferInvalidate(sampleBuffer)
            }
            guard let blockBuffer =
                CMSampleBufferGetDataBuffer(sampleBuffer) else {
                continue
            }
            var lengthAtOffset = 0
            var totalLength = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            let status = CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: &lengthAtOffset,
                totalLengthOut: &totalLength,
                dataPointerOut: &dataPointer
            )
            guard status == kCMBlockBufferNoErr,
                  let dataPointer else {
                throw AutoMixAnalysisError.invalidAudioBuffer
            }
            let availableCount =
                totalLength / MemoryLayout<Float>.stride
            let remainingCount =
                maximumSampleCount - samples.count
            let count = min(availableCount, remainingCount)
            let floats = UnsafeRawPointer(dataPointer)
                .assumingMemoryBound(to: Float.self)
            samples.append(
                contentsOf: UnsafeBufferPointer(
                    start: floats,
                    count: count
                )
            )
        }
        if reader.status == .failed {
            throw AutoMixAnalysisError.readerFailed(
                reader.error
            )
        }
        guard !samples.isEmpty else {
            throw AutoMixAnalysisError.invalidAudioBuffer
        }
        return samples
    }
}

nonisolated private enum BeatNetTemporalDecoder {
    private static let framesPerSecond = 50.0

    static func decode(
        activations: [(beat: Float, downbeat: Float)],
        energy: [Float],
        regionStart: TimeInterval
    ) -> AutoMixTrackAnalysis {
        let beatActivations = activations.map(\.beat)
        let downbeatActivations = activations.map(\.downbeat)
        let lagRange = 12...55
        let correlationScores = lagRange.map { lag in
            autocorrelation(
                values: beatActivations,
                lag: lag
            )
        }
        var bestLag = lagRange.lowerBound
        var bestScore: Float = -.infinity
        for (offset, score) in correlationScores.enumerated()
        where score > bestScore {
            bestScore = score
            bestLag = lagRange.lowerBound + offset
        }
        bestLag = correctedLag(
            bestLag,
            scores: correlationScores,
            lagRange: lagRange
        )

        let phase = strongestPhase(
            values: beatActivations,
            period: bestLag
        )
        let beatFrames = refinedBeatFrames(
            values: beatActivations,
            phase: phase,
            period: bestLag
        )
        let downbeatPhase = strongestDownbeatPhase(
            values: downbeatActivations,
            beatFrames: beatFrames
        )
        let downbeatFrames = beatFrames.enumerated()
            .compactMap { index, frame in
                index % 4 == downbeatPhase ? frame : nil
            }
        let confidence = confidence(
            beatActivations: beatActivations,
            downbeatActivations: downbeatActivations,
            beatFrames: beatFrames,
            downbeatFrames: downbeatFrames,
            correlationScore: bestScore
        )
        return AutoMixTrackAnalysis(
            bpm: framesPerSecond * 60 / Double(bestLag),
            confidence: confidence,
            beats: beatFrames.map {
                regionStart + Double($0) / framesPerSecond
            },
            downbeats: downbeatFrames.map {
                regionStart + Double($0) / framesPerSecond
            },
            regionStart: regionStart,
            normalizedEnergy: energy
        )
    }

    private static func autocorrelation(
        values: [Float],
        lag: Int
    ) -> Float {
        guard values.count > lag else { return 0 }
        var numerator: Float = 0
        var leftEnergy: Float = 0
        var rightEnergy: Float = 0
        for index in lag..<values.count {
            let left = values[index]
            let right = values[index - lag]
            numerator += left * right
            leftEnergy += left * left
            rightEnergy += right * right
        }
        return numerator
            / max(
                sqrt(leftEnergy * rightEnergy),
                .leastNonzeroMagnitude
            )
    }

    private static func correctedLag(
        _ lag: Int,
        scores: [Float],
        lagRange: ClosedRange<Int>
    ) -> Int {
        let bpm = framesPerSecond * 60 / Double(lag)
        if bpm > 180 {
            let slowerLag = lag * 2
            if lagRange.contains(slowerLag),
               score(
                   for: slowerLag,
                   scores: scores,
                   lagRange: lagRange
               ) >= score(
                   for: lag,
                   scores: scores,
                   lagRange: lagRange
               ) * 0.86 {
                return slowerLag
            }
        } else if bpm < 75 {
            let fasterLag = lag / 2
            if lagRange.contains(fasterLag),
               score(
                   for: fasterLag,
                   scores: scores,
                   lagRange: lagRange
               ) >= score(
                   for: lag,
                   scores: scores,
                   lagRange: lagRange
               ) * 0.9 {
                return fasterLag
            }
        }
        return lag
    }

    private static func score(
        for lag: Int,
        scores: [Float],
        lagRange: ClosedRange<Int>
    ) -> Float {
        scores[lag - lagRange.lowerBound]
    }

    private static func strongestPhase(
        values: [Float],
        period: Int
    ) -> Int {
        var bestPhase = 0
        var bestScore: Float = -.infinity
        for phase in 0..<period {
            var score: Float = 0
            var frame = phase
            while frame < values.count {
                score += values[frame]
                frame += period
            }
            if score > bestScore {
                bestScore = score
                bestPhase = phase
            }
        }
        return bestPhase
    }

    private static func refinedBeatFrames(
        values: [Float],
        phase: Int,
        period: Int
    ) -> [Int] {
        var frames: [Int] = []
        var nominalFrame = phase
        while nominalFrame < values.count {
            let lowerBound = max(nominalFrame - 2, 0)
            let upperBound = min(
                nominalFrame + 2,
                values.count - 1
            )
            let range = lowerBound...upperBound
            if let frame = range.max(
                by: { values[$0] < values[$1] }
            ), frames.last != frame {
                frames.append(frame)
            }
            nominalFrame += period
        }
        return frames
    }

    private static func strongestDownbeatPhase(
        values: [Float],
        beatFrames: [Int]
    ) -> Int {
        guard !beatFrames.isEmpty else { return 0 }
        return (0..<4).max { left, right in
            let leftScore = stride(
                from: left,
                to: beatFrames.count,
                by: 4
            ).reduce(Float.zero) {
                $0 + values[beatFrames[$1]]
            }
            let rightScore = stride(
                from: right,
                to: beatFrames.count,
                by: 4
            ).reduce(Float.zero) {
                $0 + values[beatFrames[$1]]
            }
            return leftScore < rightScore
        } ?? 0
    }

    private static func confidence(
        beatActivations: [Float],
        downbeatActivations: [Float],
        beatFrames: [Int],
        downbeatFrames: [Int],
        correlationScore: Float
    ) -> Double {
        let background = beatActivations.reduce(0, +)
            / Float(max(beatActivations.count, 1))
        let beatMean = beatFrames.reduce(Float.zero) {
            $0 + beatActivations[$1]
        } / Float(max(beatFrames.count, 1))
        let downbeatMean = downbeatFrames.reduce(Float.zero) {
            $0 + downbeatActivations[$1]
        } / Float(max(downbeatFrames.count, 1))
        let contrast = max(
            (beatMean - background)
                / max(1 - background, 0.01),
            0
        )
        let value =
            contrast * 0.5
            + max(correlationScore, 0) * 0.35
            + downbeatMean * 0.15
        return Double(min(max(value, 0), 1))
    }
}
