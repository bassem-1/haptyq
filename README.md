# TrackpadHaptics

Custom trackpad haptics for window actions (close, fullscreen, minimize, resize). macOS 13+, Swift 5.9.

Uses private MultitouchSupport APIs (loaded via dlopen): no App Store, and it may break with any macOS update.

1. Build: `swift build -c release` (binaries in `.build/release/`).
2. Grant **Accessibility** and **Input Monitoring** to your terminal (or the binary) in System Settings > Privacy & Security.
3. Map IDs: `.build/release/haptic-lab sweep`, then `fire <id> [f1] [f2]` and `play <pattern>` to refine.
4. Put chosen IDs in `Sources/HapticCore/Library.swift`, or override by name in `~/.config/trackpad-haptics/patterns.json`:
   `[{"name":"latch","pulses":[{"id":6,"f1":0,"f2":0,"delayMs":0},{"id":3,"f1":0,"f2":0,"delayMs":45}]}]`
5. Run: `.build/release/haptic-daemon`.
6. Web lab: `.build/release/haptic-web [port]`, then open http://127.0.0.1:47823. It has a button for each actuator ID, a range sweep, the saved patterns, a small pattern builder (`6@0, 3@45`), and ratings for each ID (kept in your browser). It only listens on localhost.
7. Proximity: as the cursor approaches a window's close button, the daemon fires taps that get faster and stronger. It also gives a light tick when the cursor enters any button. Tune this in the web lab's "Proximity playground". Settings are saved to `~/.config/trackpad-haptics/proximity.json`, and a running daemon reloads them within a second.
