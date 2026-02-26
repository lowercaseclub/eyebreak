import CoreAudio
import CoreMediaIO

enum MeetingDetector {
    static func isMeetingActive() -> Bool {
        return isMicInUse() || isCameraInUse()
    }

    private static func isMicInUse() -> Bool {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return false }

        var isRunning: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere

        let runStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isRunning)
        return runStatus == noErr && isRunning != 0
    }

    private static func isCameraInUse() -> Bool {
        var allow: UInt32 = 1
        var allowProp = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &allowProp,
            0, nil,
            UInt32(MemoryLayout<UInt32>.size),
            &allow
        )

        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        var dataSize: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject),
            &address,
            0, nil,
            &dataSize
        ) == noErr, dataSize > 0 else { return false }

        let deviceCount = Int(dataSize) / MemoryLayout<CMIODeviceID>.size
        var devices = [CMIODeviceID](repeating: 0, count: deviceCount)
        var dataUsed: UInt32 = 0

        guard CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &address,
            0, nil,
            dataSize,
            &dataUsed,
            &devices
        ) == noErr else { return false }

        for device in devices {
            var isRunning: UInt32 = 0
            let size = UInt32(MemoryLayout<UInt32>.size)
            var runAddr = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )

            var runDataUsed: UInt32 = 0
            if CMIOObjectGetPropertyData(device, &runAddr, 0, nil, size, &runDataUsed, &isRunning) == noErr,
               isRunning != 0 {
                return true
            }
        }

        return false
    }
}
