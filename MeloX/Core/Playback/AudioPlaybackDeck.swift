import AVFoundation

@MainActor
final class AudioPlaybackDeck {
    let player: AVPlayer

    var onItemStatusChanged: ((AVPlayerItem) -> Void)?
    private(set) var itemIdentifier: Int?

    private var itemStatusObserver: NSKeyValueObservation?

    init() {
        player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = true
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    func replaceCurrentItem(
        with item: AVPlayerItem,
        identifier: Int?
    ) {
        itemStatusObserver?.invalidate()
        itemIdentifier = identifier
        itemStatusObserver = item.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self, weak item] _, _ in
            guard let self, let item else { return }
            Task { @MainActor [self, item] in
                guard self.player.currentItem === item else {
                    return
                }
                self.onItemStatusChanged?(item)
            }
        }
        player.replaceCurrentItem(with: item)
    }

    func clear() {
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        itemIdentifier = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        player.rate = 0
    }
}
