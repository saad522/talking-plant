#!/bin/sh
# Sets up the Kokoro spike (docs/spikes/kokoro.md). Safe to run again.
#
# 1. Vendor/: kokoro-ios 1.0.11 and MisakiSwift 1.0.6 at their exact commits, with patches/*.patch.
#    The published versions don't build with Xcode 26: their resource bundles fail codesign, and their
#    exact pin to mlx-swift 0.30.2 has iOS 26 link errors and gives wrong audio on A18/A19 chips.
#    The patches move to mlx-swift 0.30.6 and flatten the resource bundles. Nothing else changes.
# 2. Models/: the Kokoro weights and voices (about 340 MB), checksum-verified.
set -eu
root="$(cd "$(dirname "$0")" && pwd)"

vendor() {
    name="$1"; url="$2"; commit="$3"
    dir="$root/Vendor/$name"
    if [ -f "$dir/.spike-patched" ]; then
        echo "$name already vendored"
        return
    fi
    echo "Vendoring $name at $commit"
    rm -rf "$dir"
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" fetch -q --depth 1 "$url" "$commit"
    git -C "$dir" checkout -q FETCH_HEAD
    patch -s -p2 -d "$dir" < "$root/patches/$name.patch"
    touch "$dir/.spike-patched"
}

vendor kokoro-ios https://github.com/mlalma/kokoro-ios.git 4d6d1d8ff8cd012014180c9cd4cf0151e7682354
vendor MisakiSwift https://github.com/mlalma/MisakiSwift.git 6835a1ce4a8854075c89f18ff75c74b13ef58e15

# Model files from mlalma/KokoroTestApp, pinned to one commit: the files kokoro-ios 1.0.x is tested with.
models="$root/Sources/KokoroSpikeEngine/Resources/Models"
commit="9dcd3b06468a3c1ecee6d09a33ca687c8e708566"

# The weights are in Git LFS: checked against the LFS SHA-256.
weights="$models/kokoro-v1_0.safetensors"
weights_sha256="4e9ecdf03b8b6cf906070390237feda473dc13327cb8d56a43deaa374c02acd8"
if [ "$(shasum -a 256 "$weights" 2>/dev/null | cut -d' ' -f1)" != "$weights_sha256" ]; then
    echo "Downloading kokoro-v1_0.safetensors (327 MB)"
    curl -fL --progress-bar -o "$weights.part" "https://media.githubusercontent.com/media/mlalma/KokoroTestApp/$commit/Resources/kokoro-v1_0.safetensors"
    [ "$(shasum -a 256 "$weights.part" | cut -d' ' -f1)" = "$weights_sha256" ] || { echo "Checksum mismatch" >&2; rm -f "$weights.part"; exit 1; }
    mv "$weights.part" "$weights"
else
    echo "kokoro-v1_0.safetensors already there"
fi

# The voices are a plain Git file: checked against the Git blob hash.
voices="$models/voices.npz"
voices_blob="8e8efa95b237d2269496403badeffd751544b540"
if [ "$(git hash-object "$voices" 2>/dev/null)" != "$voices_blob" ]; then
    echo "Downloading voices.npz (14.6 MB)"
    curl -fL --progress-bar -o "$voices.part" "https://raw.githubusercontent.com/mlalma/KokoroTestApp/$commit/Resources/voices.npz"
    [ "$(git hash-object "$voices.part")" = "$voices_blob" ] || { echo "Checksum mismatch" >&2; rm -f "$voices.part"; exit 1; }
    mv "$voices.part" "$voices"
else
    echo "voices.npz already there"
fi

echo "Done. In Xcode: File > Packages > Reset Package Caches if Xcode resolved before, then Product > Clean Build Folder."
