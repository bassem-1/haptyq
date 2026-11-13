# haptyq

haptyq is a macOS menu bar app that makes your force touch trackpad react to where the cursor is.
near the red close button the trackpad pulses faster and harder ("frenzy"); near full screen it only taps once ("tick").

_demo gif coming soon._

haptyq uses private MultitouchSupport and accessibility APIs, so it is not on the mac app store. it is distributed as an
ad-hoc signed zip on github releases, without a paid apple developer account.

## requirements

- macOS 13 or later, with a force touch trackpad (haptyq still runs without one, but nothing will vibrate).

## install

1. download `haptyq-<version>.zip` from the latest release and unzip it.
2. move `haptyq.app` to `/Applications`.
3. open it for the first time:
   - macOS 15 or later: try to open it, then go to system settings › privacy & security and click "open anyway".
   - macOS 13 or 14: right-click `haptyq.app` and choose "open", then confirm.
   - or run `xattr -dr com.apple.quarantine /Applications/haptyq.app` in terminal.
4. grant accessibility access when haptyq asks. it needs this to see where the window buttons are.

ad-hoc builds are not tied to an apple developer identity, so macOS may ask for accessibility access again after each
update. toggle haptyq off and on in system settings › privacy & security › accessibility.

## use

open haptyq like any app (spotlight, launchpad or /Applications). its window has two halves:

- **playground** (left): a mock window with close, minimize and full screen buttons. rings show how far out each one
  reacts. move the cursor toward them to feel it live.
- **inspector** (right): pick a button, then set its **rhythm** (off, tick, calm, ramp, frenzy), **reach** (10-300 pt),
  **strength** (1-4), whether a real click gets a confirmation pattern, and **feel it** to preview it.

close the window and haptyq keeps running in the menu bar (three yellow bars). open the app again to get the window
back. the desktop gadget shows whether haptyq is on: click to pause or resume, drag to move, right-click for options.

## build from source

haptyq is a swift package. with xcode or the command line tools (`xcode-select --install`) installed:

    git clone https://github.com/bassem-1/haptyq
    cd haptyq
    scripts/bundle.sh
    open dist/haptyq.app

apps you build yourself are not quarantined, so gatekeeper will not block them. to run the tests:

    swift test

to build a universal (apple silicon and intel) bundle the way releases are built:

    scripts/bundle.sh --universal

the output is `dist/haptyq.app` and `dist/haptyq-<version>.zip`. the universal build needs xcode.

the version lives in `VERSION` at the repo root.

## calibrating haptics

the actuator ids that haptyq uses differ between trackpads. to tune them, run the web lab:

    swift run haptic-web

then open the address it prints. it listens on localhost only.

## a note on private apis

haptyq depends on private apple frameworks. they can change or disappear in any macOS update, and this project is not
affiliated with apple. use it at your own risk.

## license

mit. see [license](LICENSE).
