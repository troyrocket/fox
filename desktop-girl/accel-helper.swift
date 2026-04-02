// Standalone accelerometer helper — runs as root, outputs slap events to stdout
import Foundation
import IOKit
import IOKit.hid

setbuf(stdout, nil)

let threshold: Double = 0.05
let cooldown: TimeInterval = 0.75
var lastSlapTime: TimeInterval = 0
var baseX: Double = 0, baseY: Double = 0, baseZ: Double = 1.0
var calibrated = false
var sampleCount = 0

// Wake SPU drivers
func wakeSPU() {
    let matching = IOServiceMatching("AppleSPUHIDDriver")
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return }
    var service = IOIteratorNext(iterator)
    while service != 0 {
        let one = 1 as CFNumber
        let interval = 1000 as CFNumber
        IORegistryEntrySetCFProperty(service, "SensorPropertyReportingState" as CFString, one)
        IORegistryEntrySetCFProperty(service, "SensorPropertyPowerState" as CFString, one)
        IORegistryEntrySetCFProperty(service, "ReportInterval" as CFString, interval)
        IOObjectRelease(service)
        service = IOIteratorNext(iterator)
    }
    IOObjectRelease(iterator)
}

wakeSPU()

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let matching: [String: Any] = [kIOHIDPrimaryUsagePageKey as String: 0xFF00, kIOHIDPrimaryUsageKey as String: 3]
IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

let callback: IOHIDReportCallback = { context, result, sender, type, reportID, report, reportLength in
    guard reportLength == 22 else { return }
    var xRaw: Int32 = 0, yRaw: Int32 = 0, zRaw: Int32 = 0
    memcpy(&xRaw, report + 6, 4)
    memcpy(&yRaw, report + 10, 4)
    memcpy(&zRaw, report + 14, 4)
    let x = Double(xRaw) / 65536.0
    let y = Double(yRaw) / 65536.0
    let z = Double(zRaw) / 65536.0

    if !calibrated {
        sampleCount += 1
        baseX += (x - baseX) / Double(sampleCount)
        baseY += (y - baseY) / Double(sampleCount)
        baseZ += (z - baseZ) / Double(sampleCount)
        if sampleCount >= 200 { calibrated = true }
        return
    }

    let dx = x - baseX, dy = y - baseY, dz = z - baseZ
    let magnitude = sqrt(dx * dx + dy * dy + dz * dz)

    if magnitude > threshold {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastSlapTime > cooldown {
            lastSlapTime = now
            let force = min(magnitude, 5.0)
            print(String(format: "SLAP:%.2f", force))
        }
    }
}

IOHIDManagerRegisterInputReportCallback(manager, callback, nil)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
if result != kIOReturnSuccess {
    fputs("ERROR:Failed to open accelerometer (need sudo)\n", stderr)
    exit(1)
}

fputs("READY\n", stdout)
CFRunLoopRun()
