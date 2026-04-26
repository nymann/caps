import Cocoa
import CoreGraphics

// Caps Lock is remapped to F19 (virtual keycode 0x50) via hidutil.
// F19 fires normal keyDown/keyUp events, unlike Caps Lock which is a toggle.
let HYPER_TRIGGER: CGKeyCode = 0x50
let ESCAPE: CGKeyCode = 0x35
let HYPER_FLAGS: CGEventFlags = [.maskCommand, .maskAlternate,
                                 .maskControl, .maskShift]
let TAP_TIMEOUT: TimeInterval = 0.2

var hyperHeld = false
var consumedWhileHeld = false
var hyperDownTime: TimeInterval = 0
var tapRef: CFMachPort?

let DEBUG = ProcessInfo.processInfo.environment["CAPS_DEBUG"] != nil

func dlog(_ s: String) {
    if DEBUG { fputs(s + "\n", stderr) }
}

func callback(proxy: CGEventTapProxy,
              type: CGEventType,
              event: CGEvent,
              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = tapRef { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }

    let keycode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

    dlog(String(format: "EV type=%d kc=0x%02x flags=0x%llx hyperHeld=%@",
                type.rawValue, keycode, event.flags.rawValue,
                hyperHeld ? "Y" : "N"))

    if keycode == HYPER_TRIGGER {
        if type == .keyDown {
            if !hyperHeld {
                hyperHeld = true
                consumedWhileHeld = false
                hyperDownTime = ProcessInfo.processInfo.systemUptime
            }
            return nil
        }
        if type == .keyUp {
            hyperHeld = false
            let held = ProcessInfo.processInfo.systemUptime - hyperDownTime
            if !consumedWhileHeld && held < TAP_TIMEOUT {
                postKey(ESCAPE)
            }
            return nil
        }
    }

    if hyperHeld, type == .keyDown || type == .keyUp {
        consumedWhileHeld = true
        event.flags = event.flags.union(HYPER_FLAGS)
    }

    return Unmanaged.passUnretained(event)
}

func postKey(_ code: CGKeyCode) {
    let src = CGEventSource(stateID: .hidSystemState)
    CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)?
        .post(tap: .cghidEventTap)
    CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)?
        .post(tap: .cghidEventTap)
}

let mask: CGEventMask =
    (1 << CGEventType.keyDown.rawValue) |
    (1 << CGEventType.keyUp.rawValue)

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                  place: .headInsertEventTap,
                                  options: .defaultTap,
                                  eventsOfInterest: mask,
                                  callback: callback,
                                  userInfo: nil) else {
    fputs("caps: failed to create event tap. Grant Accessibility permission to this binary in System Settings → Privacy & Security → Accessibility, then re-run.\n", stderr)
    exit(1)
}
tapRef = tap

let runLoopSrc = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSrc, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
CFRunLoopRun()
