import ApplicationServices
import CoreGraphics
import Foundation
import HapticCore

let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
guard AXIsProcessTrustedWithOptions(opts) else {
    print("Accessibility permission required. Grant it in System Settings > Privacy & Security, then relaunch.")
    exit(1)
}
guard let actuator = Actuator() else { print("No actuator"); exit(1) }

let patterns = Library.load()
let player = PatternPlayer(actuator: actuator)
let systemWide = AXUIElementCreateSystemWide()
AXUIElementSetMessagingTimeout(systemWide, 0.05) // never stall the tap on a hung app
let proximity = ProximityEngine(actuator: actuator)

// MARK: AX helpers

func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}

func element(_ v: CFTypeRef?) -> AXUIElement? {
    guard let v, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
    return (v as! AXUIElement)
}

func frame(of window: AXUIElement) -> CGRect? {
    guard let p = attr(window, kAXPositionAttribute), let s = attr(window, kAXSizeAttribute) else { return nil }
    var origin = CGPoint.zero, size = CGSize.zero
    guard AXValueGetValue(p as! AXValue, .cgPoint, &origin),
          AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
    return CGRect(origin: origin, size: size)
}

func nearEdge(_ pt: CGPoint, of r: CGRect, within d: CGFloat = 6) -> Bool {
    guard r.insetBy(dx: -d, dy: -d).contains(pt) else { return false }
    return !r.insetBy(dx: d, dy: d).contains(pt)
}

// MARK: State

let buttonPatterns: [String: String] = [
    "AXFullScreenButton": "inhale", "AXZoomButton": "inhale", "AXMinimizeButton": "sink",
]
var pendingPattern: String?
var resizing = false
var accumulated: CGFloat = 0
let ratchetStep: CGFloat = 40

func play(_ name: String, after ms: Int = 0) {
    if let p = patterns[name] { player.play(p, afterMs: ms) }
}

func handleDown(_ pt: CGPoint) {
    pendingPattern = nil
    resizing = false
    accumulated = 0

    var found: AXUIElement?
    guard AXUIElementCopyElementAtPosition(systemWide, Float(pt.x), Float(pt.y), &found) == .success,
          let el = found else { return }

    let role = attr(el, kAXRoleAttribute) as? String
    let window = role == kAXWindowRole ? el : element(attr(el, kAXWindowAttribute))

    if let sub = attr(el, kAXSubroleAttribute) as? String, sub.hasSuffix("Button") {
        if sub == "AXCloseButton" {
            let modified = (window.flatMap { attr($0, "AXModified") } as? Bool) == true
            pendingPattern = modified ? "heartbeat" : "latch"
        } else {
            pendingPattern = buttonPatterns[sub]
        }
        return
    }

    if let window, let r = frame(of: window), nearEdge(pt, of: r) {
        resizing = true
    }
}

func handleDrag(dx: CGFloat, dy: CGFloat) {
    guard resizing else { return }
    accumulated += hypot(dx, dy)
    while accumulated >= ratchetStep {
        accumulated -= ratchetStep
        play("ratchet")
    }
}

func handleUp() {
    // Delay to avoid colliding with the system click haptic.
    if let name = pendingPattern { play(name, after: 60) }
    pendingPattern = nil
    resizing = false
}

// MARK: Hover / proximity

var cursor = CGPoint.zero
var lastLookup = DispatchTime(uptimeNanoseconds: 0)
var closeTargets: [CGRect] = []
var hoveredButton: AXUIElement?

func closeButtonFrame(_ window: AXUIElement?) -> CGRect? {
    guard let window, let btn = element(attr(window, kAXCloseButtonAttribute)) else { return nil }
    return frame(of: btn)
}

/// Refresh close-button targets (window under cursor + focused window) and fire a hover tick on entering a button.
func lookup(_ pt: CGPoint) {
    var found: AXUIElement?
    var underWindow: AXUIElement?
    var button: AXUIElement?
    if AXUIElementCopyElementAtPosition(systemWide, Float(pt.x), Float(pt.y), &found) == .success, let el = found {
        let role = attr(el, kAXRoleAttribute) as? String
        underWindow = role == kAXWindowRole ? el : element(attr(el, kAXWindowAttribute))
        if role == kAXButtonRole { button = el }
    }
    let app = element(attr(systemWide, kAXFocusedApplicationAttribute))
    let focused = app.flatMap { element(attr($0, kAXFocusedWindowAttribute)) }
    closeTargets = [closeButtonFrame(underWindow), closeButtonFrame(focused)].compactMap { $0 }

    let entered: Bool
    switch (button, hoveredButton) {
    case (let b?, let h?): entered = !CFEqual(b, h)
    case (.some, nil): entered = true
    default: entered = false
    }
    hoveredButton = button
    if entered, proximity.config.hoverTick { play("ratchet") }
}

func distance(_ pt: CGPoint, to r: CGRect) -> Double {
    // Distance from the point to the (round) button's edge; 0 when on it.
    let radius = min(r.width, r.height) / 2
    return max(0, Double(hypot(pt.x - r.midX, pt.y - r.midY) - radius))
}

func handleMove(_ pt: CGPoint) {
    cursor = pt
    let now = DispatchTime.now()
    if now.uptimeNanoseconds - lastLookup.uptimeNanoseconds > 50_000_000 { // AX lookups at most every 50 ms
        lastLookup = now
        lookup(pt)
    }
    proximity.update(distance: closeTargets.map { distance(pt, to: $0) }.min())
}

// Reload proximity.json when haptic-web (or you) changes it.
var configStamp = (try? FileManager.default.attributesOfItem(atPath: ProximityConfig.url.path)[.modificationDate]) as? Date
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    let stamp = (try? FileManager.default.attributesOfItem(atPath: ProximityConfig.url.path)[.modificationDate]) as? Date
    if stamp != configStamp {
        configStamp = stamp
        proximity.config = ProximityConfig.load()
        print("reloaded proximity config")
    }
}

// MARK: Event tap

var tap: CFMachPort?

let callback: CGEventTapCallBack = { _, type, event, _ in
    switch type {
    case .mouseMoved: handleMove(event.location)
    case .leftMouseDown:
        proximity.update(distance: nil) // let the click pattern play cleanly
        handleDown(event.location)
    case .leftMouseDragged:
        handleDrag(dx: CGFloat(event.getDoubleValueField(.mouseEventDeltaX)),
                   dy: CGFloat(event.getDoubleValueField(.mouseEventDeltaY)))
    case .leftMouseUp: handleUp()
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    default: break
    }
    return Unmanaged.passUnretained(event)
}

let mask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)
    | (1 << CGEventType.leftMouseDown.rawValue)
    | (1 << CGEventType.leftMouseUp.rawValue)
    | (1 << CGEventType.leftMouseDragged.rawValue)

guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                      options: .listenOnly, eventsOfInterest: mask,
                                      callback: callback, userInfo: nil) else {
    print("Could not create event tap. Grant Input Monitoring to this terminal/binary.")
    exit(1)
}
tap = created
CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, created, 0), .commonModes)
CGEvent.tapEnable(tap: created, enable: true)
print("haptic-daemon running")
CFRunLoopRun()
