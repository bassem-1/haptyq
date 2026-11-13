#!/usr/bin/env bash
# builds tremor, assembles dist/tremor.app, ad-hoc signs it and zips it for a github release.
# usage: scripts/bundle.sh [--universal]
set -euo pipefail

usage() {
    echo "usage: scripts/bundle.sh [--universal]" >&2
    exit 2
}

universal=0
for arg in "$@"; do
    case "$arg" in
        --universal) universal=1 ;;
        *) usage ;;
    esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

app_name="tremor"
version="$(tr -d '[:space:]' < "$root/VERSION")"
if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    echo "error: VERSION must be dotted numbers, got '$version'" >&2
    exit 1
fi

dist="$root/dist"
app="$dist/$app_name.app"
zip_path="$dist/$app_name-$version.zip"
work="${TREMOR_BUILD_DIR:-$root/.build}/bundle"

# TREMOR_BUILD_DIR moves build products elsewhere (useful when the repo lives in an iCloud-synced folder).
build_args=(-c release --scratch-path "${TREMOR_BUILD_DIR:-$root/.build}")
if [[ $universal -eq 1 ]]; then
    build_args+=(--arch arm64 --arch x86_64)
fi

echo "building $app_name $version (${build_args[*]})"
swift build "${build_args[@]}"
bin_dir="$(swift build "${build_args[@]}" --show-bin-path)"
binary="$bin_dir/$app_name"
if [[ ! -x "$binary" ]]; then
    echo "error: built binary not found at $binary" >&2
    exit 1
fi

echo "rendering icon"
rm -rf "$work"
mkdir -p "$work/AppIcon.iconset"
master="$work/icon-1024.png"
swift "$root/scripts/make-icon.swift" "$master"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$master" --out "$work/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$master" --out "$work/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$work/AppIcon.iconset" -o "$work/AppIcon.icns"

echo "assembling $app"
rm -rf "$dist"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/$app_name"
chmod 755 "$app/Contents/MacOS/$app_name"
sed -e "s/__VERSION__/$version/g" "$root/Resources/Info.plist" > "$app/Contents/Info.plist"
plutil -lint "$app/Contents/Info.plist" >/dev/null
cp "$work/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"

echo "signing (ad-hoc)"
codesign --force --sign - --timestamp=none "$app"
codesign --verify --deep --strict "$app"

echo "zipping $zip_path"
ditto -c -k --keepParent "$app" "$zip_path"
shasum -a 256 "$zip_path"
