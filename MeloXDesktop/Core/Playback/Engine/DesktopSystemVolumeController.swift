import AudioToolbox
import CoreAudio

nonisolated enum DesktopSystemVolumeController {
    static func volume() -> Double? {
        guard let deviceID = defaultOutputDevice() else { return nil }

        for address in volumeAddresses {
            if let value = readVolume(on: deviceID, address: address) {
                return Double(value)
            }
        }

        let channelVolumes = [UInt32(1), UInt32(2)].compactMap { channel in
            readVolume(
                on: deviceID,
                address: volumeAddress(
                    selector: kAudioDevicePropertyVolumeScalar,
                    element: channel
                )
            )
        }
        guard !channelVolumes.isEmpty else { return nil }
        return Double(channelVolumes.reduce(0, +) / Float32(channelVolumes.count))
    }

    @discardableResult
    static func setVolume(_ value: Double) -> Bool {
        guard let deviceID = defaultOutputDevice() else { return false }
        var scalar = Float32(min(max(value, 0), 1))

        for address in volumeAddresses where isSettable(on: deviceID, address: address) {
            var mutableAddress = address
            let status = AudioObjectSetPropertyData(
                deviceID,
                &mutableAddress,
                0,
                nil,
                UInt32(MemoryLayout<Float32>.size),
                &scalar
            )
            if status == noErr {
                return true
            }
        }

        var changedChannel = false
        for channel in [UInt32(1), UInt32(2)] {
            var address = volumeAddress(
                selector: kAudioDevicePropertyVolumeScalar,
                element: channel
            )
            guard isSettable(on: deviceID, address: address) else { continue }
            let status = AudioObjectSetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<Float32>.size),
                &scalar
            )
            changedChannel = changedChannel || status == noErr
        }
        return changedChannel
    }

    private static var volumeAddresses: [AudioObjectPropertyAddress] {
        [
            volumeAddress(
                selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                element: kAudioObjectPropertyElementMain
            ),
            volumeAddress(
                selector: kAudioDevicePropertyVolumeScalar,
                element: kAudioObjectPropertyElementMain
            ),
        ]
    }

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private static func readVolume(
        on deviceID: AudioDeviceID,
        address: AudioObjectPropertyAddress
    ) -> Float32? {
        var mutableAddress = address
        guard AudioObjectHasProperty(deviceID, &mutableAddress) else { return nil }
        var scalar = Float32.zero
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &mutableAddress,
            0,
            nil,
            &size,
            &scalar
        )
        guard status == noErr else { return nil }
        return min(max(scalar, 0), 1)
    }

    private static func isSettable(
        on deviceID: AudioDeviceID,
        address: AudioObjectPropertyAddress
    ) -> Bool {
        var mutableAddress = address
        guard AudioObjectHasProperty(deviceID, &mutableAddress) else { return false }
        var settable = DarwinBoolean(false)
        let status = AudioObjectIsPropertySettable(
            deviceID,
            &mutableAddress,
            &settable
        )
        return status == noErr && settable.boolValue
    }

    private static func volumeAddress(
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }
}
