# haptyk

haptyk is a macOS menu bar app that makes your force touch trackpad react to where the cursor is.
near the red close button the trackpad pulses faster and harder ("frenzy"); near full screen it only taps once ("tick").

_demo gif coming soon._

haptyk uses private MultitouchSupport and accessibility APIs, so it is not on the mac app store. it is distributed as an
ad-hoc signed zip on github releases, without a paid apple developer account.

## requirements

- macOS 13 or later, with a force touch trackpad (haptyk still runs without one, but nothing will vibrate).

## install

1. download `haptyk-<version>.zip` from the latest release and unzip it.
2. move `haptyk.app` to `/Applications`.
3. open it for the first time:
   - macOS 15 or later: try to open it, then go to system settings › privacy & security and click "open anyway".
   - macOS 13 or 14: right-click `haptyk.app` and choose "open", then confirm.
   - or run `xattr -dr com.apple.quarantine /Applications/haptyk.app` in terminal.
4. grant accessibility access when haptyk asks. it needs this to see where the window buttons are.

ad-hoc builds are not tied to an apple developer identity, so macOS may ask for accessibility access again after each
update. toggle haptyk off and on in system settings › privacy & security › accessibility.

## use

click the menu bar icon (three yellow bars) to open the panel:

- each zone (close, minimize, full screen, other buttons, window edges) has a signal bar. click a cell to set how strong
  the feel is, from off to frenzy.
- click a zone's name to see its reach, whether a click needs to be confirmed, and a "feel it" preview.
- the desktop gadget shows the state of haptyk. click it to pause or resume, drag it to move it, and right-click it for
  more options.

## build from source

haptyk is a swift package. with xcode or the command line tools installed:

    swift build -c release
    swift test

to build the app bundle and zip it the same way the releases are built:

    scripts/bundle.sh --universal

the output is `dist/haptyk.app` and `dist/haptyk-<version>.zip`. the universal build needs xcode.

the version lives in `VERSION` at the repo root.

## calibrating haptics

the actuator ids that haptyk uses differ between trackpads. to tune them, run the web lab:

    swift run haptic-web

then open the address it prints. it listens on localhost only.

## a note on private apis

haptyk depends on private apple frameworks. they can change or disappear in any macOS update, and this project is not
affiliated with apple. use it at your own risk.

## license

mit. see [license](LICENSE).
