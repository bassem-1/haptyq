import AppKit
import Foundation

/// Wraps the private MultitouchSupport actuator (loaded at runtime, never linked).
public final class Actuator {
    private typealias CreateDefaultFn = @convention(c) () -> UnsafeMutableRawPointer?
    private typealias GetDeviceIDFn = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32
    // Returns a +1 retained CFTypeRef (Unmanaged<CFTypeRef>? in spirit); handled as a raw pointer for C ABI safety.
    private typealias ActCreateFn = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    private typealias ActOpenFn = @convention(c) (UnsafeRawPointer) -> Int32
    private typealias ActActuateFn = @convention(c) (UnsafeRawPointer, Int32, UInt32, Float, Float) -> Int32
    private typealias ActCloseFn = @convention(c) (UnsafeRawPointer) -> Int32

    private var handle: UnsafeMutableRawPointer?
    private var actuator: UnsafeMutableRawPointer?
    private var actuate: ActActuateFn?
    private var close: ActCloseFn?
    // fire() is called from several queues (proximity, patterns, tracker); the private api isn't known to be reentrant.
    private let lock = NSLock()
    private var _onFire: (() -> Void)?

    /// Called after every fire attempt, on whichever queue fired. Keep it cheap.
    public var onFire: (() -> Void)? {
        get { lock.lock(); defer { lock.unlock() }; return _onFire }
        set { lock.lock(); _onFire = newValue; lock.unlock() }
    }

    public init?() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let h = dlopen(path, RTLD_NOW) else { return }
        handle = h

        func sym<T>(_ name: String, _ type: T.Type) -> T? {
            guard let p = dlsym(h, name) else { return nil }
            return unsafeBitCast(p, to: type)
        }
        guard let createDefault = sym("MTDeviceCreateDefault", CreateDefaultFn.self),
              let getID = sym("MTDeviceGetDeviceID", GetDeviceIDFn.self),
              let create = sym("MTActuatorCreateFromDeviceID", ActCreateFn.self),
              let open = sym("MTActuatorOpen", ActOpenFn.self),
              let act = sym("MTActuatorActuate", ActActuateFn.self),
              let cls = sym("MTActuatorClose", ActCloseFn.self),
              let dev = createDefault() else { return }

        var deviceID: UInt64 = 0
        guard getID(dev, &deviceID) == 0, let a = create(deviceID) else { return }
        guard open(UnsafeRawPointer(a)) == 0 else {
            Unmanaged<CFTypeRef>.fromOpaque(a).release()
            return
        }
        actuator = a
        actuate = act
        close = cls
    }

    deinit {
        if let a = actuator {
            _ = close?(UnsafeRawPointer(a))
            Unmanaged<CFTypeRef>.fromOpaque(a).release()
        }
        if let h = handle { dlclose(h) }
    }

    /// Fires an actuation; falls back to the public generic haptic if the private path is unavailable or fails.
    @discardableResult
    public func fire(id: Int32, f1: Float = 0, f2: Float = 0) -> Bool {
        lock.lock()
        var ok = false
        if let a = actuator, let act = actuate { ok = act(UnsafeRawPointer(a), id, 0, f1, f2) == 0 }
        let hook = _onFire
        lock.unlock()
        if !ok {
            DispatchQueue.main.async {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
        }
        hook?()
        return ok
    }
}
