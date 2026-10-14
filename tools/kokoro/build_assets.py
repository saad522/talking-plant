#!/usr/bin/env python3
"""Builds the Kokoro files PlantKokoro ships (docs/plans/M5c-kokoro.md, section 6).

Writes sprout.safetensors and kokoro-f16.safetensors (weight norm folded, see fold_weight_norm) into
ios/PlantKokoro/Sources/PlantKokoro/Resources/, checks them, and prints a size report.
"""
import argparse
import hashlib
import io
import sys
import urllib.request
import zipfile
from collections import defaultdict
from pathlib import Path

import mlx.core as mx
import numpy as np

HERE = Path(__file__).resolve().parent
CACHE = HERE / ".cache"
CHECKSUMS = HERE / "assets.sha256"
OUTPUT = HERE.parent.parent / "ios/PlantKokoro/Sources/PlantKokoro/Resources"

# Same pinned files as ios/KokoroSpike/setup.sh (mlalma/KokoroTestApp).
COMMIT = "9dcd3b06468a3c1ecee6d09a33ca687c8e708566"
WEIGHTS_URL = f"https://media.githubusercontent.com/media/mlalma/KokoroTestApp/{COMMIT}/Resources/kokoro-v1_0.safetensors"
WEIGHTS_SHA256 = "4e9ecdf03b8b6cf906070390237feda473dc13327cb8d56a43deaa374c02acd8"
VOICES_URL = f"https://raw.githubusercontent.com/mlalma/KokoroTestApp/{COMMIT}/Resources/voices.npz"
VOICES_GIT_BLOB = "8e8efa95b237d2269496403badeffd751544b540"

HEART_WEIGHT = 0.45
NICOLE_WEIGHT = 0.55
QUANT_GROUP = 64
MB = 1_000_000


def fail(message):
    sys.exit(f"error: {message}")


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as file:
        for block in iter(lambda: file.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def git_blob_hash(path):
    data = path.read_bytes()
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def download(url, target, verify):
    if target.exists() and verify(target):
        return
    CACHE.mkdir(exist_ok=True)
    part = target.with_suffix(target.suffix + ".part")
    print(f"downloading {target.name}")
    with urllib.request.urlopen(url) as response, open(part, "wb") as file:
        while block := response.read(1 << 20):
            file.write(block)
    if not verify(part):
        part.unlink()
        fail(f"checksum mismatch for {target.name}")
    part.replace(target)


def load_voice(archive, name):
    with zipfile.ZipFile(archive) as zipped:
        return np.load(io.BytesIO(zipped.read(f"{name}.npy")))


def make_sprout(voices):
    heart = load_voice(voices, "af_heart").astype(np.float32)
    nicole = load_voice(voices, "af_nicole").astype(np.float32)
    if heart.shape != (510, 1, 256) or nicole.shape != heart.shape:
        fail(f"unexpected voice shape {heart.shape} / {nicole.shape}")
    sprout = heart * np.float32(HEART_WEIGHT) + nicole * np.float32(NICOLE_WEIGHT)
    return heart, nicole, sprout


def check_sprout(path, heart, nicole):
    saved = np.array(mx.load(str(path))["sprout"])
    wide = heart.astype(np.float64) * HEART_WEIGHT + nicole.astype(np.float64) * NICOLE_WEIGHT
    worst = float(np.max(np.abs(saved.astype(np.float64) - wide)))
    if saved.shape != heart.shape or saved.dtype != np.float32 or worst > 1e-6:
        fail(f"sprout is not 0.45*heart + 0.55*nicole (worst difference {worst})")
    return worst


def component(key):
    return key.split(".")[0]


def is_float(array):
    return array.dtype in (mx.float32, mx.float16, mx.bfloat16)


def fold_weight_norm(weights):
    """Replaces every `<name>.weight_g` / `<name>.weight_v` pair with `<name>.weight`.

    This is what kokoro-ios computed on every call: g * v / (||v|| + 1e-7), with the norm over all
    axes except 0. Done once here, in float32, so the app does no weight-norm math and never holds
    the float32 intermediates. The result has weight_v's shape, so the app's transposition rule
    for weight_v applies to it unchanged.
    """
    folded = {}
    count = 0
    for key, array in weights.items():
        if key.endswith(".weight_g"):
            continue
        if not key.endswith(".weight_v"):
            folded[key] = array
            continue
        prefix = key[: -len("weight_v")]
        g = weights[prefix + "weight_g"].astype(mx.float32)
        v = array.astype(mx.float32)
        norm = mx.sqrt(mx.sum(v * v, axis=tuple(range(1, v.ndim)), keepdims=True))
        name = prefix + "weight"
        if name in weights:
            fail(f"{name} already exists next to {key}")
        folded[name] = g * (v / (norm + 1e-7))
        count += 1
    mx.eval(folded)
    return folded, count


def check_fold(original, folded, count):
    """Recomputes every folded weight in float64 with numpy and compares."""
    pairs = [key[: -len("weight_v")] for key in original if key.endswith(".weight_v")]
    if len(pairs) != count or any(key.endswith((".weight_g", ".weight_v")) for key in folded):
        fail("weight_g / weight_v pairs are left over after folding")
    worst = 0.0
    for prefix in pairs:
        v = np.array(original[prefix + "weight_v"].astype(mx.float32), dtype=np.float64)
        g = np.array(original[prefix + "weight_g"].astype(mx.float32), dtype=np.float64)
        norm = np.sqrt(np.sum(v * v, axis=tuple(range(1, v.ndim)), keepdims=True))
        expected = g * v / (norm + 1e-7)
        got = np.array(folded[prefix + "weight"], dtype=np.float64)
        if got.shape != v.shape:
            fail(f"{prefix}weight has shape {got.shape}, expected {v.shape}")
        worst = max(worst, float(np.max(np.abs(got - expected))))
    if worst > 1e-5:
        fail(f"folded weights differ from the float64 reference by {worst}")
    print(f"weight norm: {count} folded weights match a float64 reference (worst difference {worst:.2e})")


def check_fp16(original, converted):
    worst = 0.0
    for key, array in original.items():
        out = converted[key]
        if not is_float(array):
            if out.dtype != array.dtype or not bool(mx.array_equal(array, out)):
                fail(f"{key}: non-float tensor changed")
            continue
        if out.dtype != mx.float16 or out.shape != array.shape:
            fail(f"{key}: expected float16 {array.shape}, got {out.dtype} {out.shape}")
        a = np.array(array.astype(mx.float32))
        b = np.array(out.astype(mx.float32))
        if not np.all(np.isfinite(b)):
            fail(f"{key}: overflows float16")
        # fp16 keeps 11 significant bits: half a unit in the last place, plus the subnormal floor.
        allowed = np.abs(a) * 2.0**-11 + 2.0**-25
        excess = float(np.max(np.abs(a - b) - allowed))
        if excess > 0:
            fail(f"{key}: float16 round trip is off by more than fp16 precision")
        worst = max(worst, float(np.max(np.abs(a - b))))
    return worst


def quantization_row(key, array):
    """(can quantize, reason or None, bytes at 8-bit, max abs round-trip error)"""
    if array.ndim == 3:
        return False, "3-D conv weight: MLX has no quantized convolution", None, None
    if "weight_ih_l" in key or "weight_hh_l" in key:
        return False, "LSTM matrix: kokoro-ios multiplies it by hand, not through Linear", None, None
    if array.ndim != 2 or not key.endswith(".weight"):
        return False, "not a Linear / Embedding weight", None, None
    if array.shape[-1] % QUANT_GROUP:
        return False, f"last dimension {array.shape[-1]} is not a multiple of {QUANT_GROUP}", None, None
    w = array.astype(mx.float32)
    q, scales, biases = mx.quantize(w, group_size=QUANT_GROUP, bits=8)
    back = mx.dequantize(q, scales, biases, group_size=QUANT_GROUP, bits=8)
    error = float(mx.max(mx.abs(w - back)))
    size = q.nbytes + scales.nbytes + biases.nbytes
    return True, None, size, error


def report(weights, f16_path, sprout_path):
    params = defaultdict(int)
    for key, array in weights.items():
        params[component(key)] += array.size
    total = sum(params.values())

    print("\n== Files ==")
    for path in (sprout_path, f16_path):
        print(f"{path.name:28s} {path.stat().st_size / MB:9.2f} MB")

    print("\n== Weights by component (parameters, fp32 MB, fp16 MB) ==")
    for name, count in sorted(params.items(), key=lambda item: -item[1]):
        print(f"{name:20s} {count:12,d} {count * 4 / MB:9.2f} {count * 2 / MB:9.2f}")
    print(f"{'total':20s} {total:12,d} {total * 4 / MB:9.2f} {total * 2 / MB:9.2f}")

    print("\n== 8-bit (for the record, not shipped) ==")
    saved_bytes = 0
    quantizable = 0
    blocked = defaultdict(lambda: [0, 0])
    rows = []
    for key, array in weights.items():
        if not is_float(array):
            continue
        ok, reason, size, error = quantization_row(key, array)
        if ok:
            quantizable += array.size
            saved_bytes += array.size * 2 - size
            rows.append((key, array.shape, array.size * 2, size, error))
        else:
            blocked[reason][0] += 1
            blocked[reason][1] += array.size
    print(f"MLX could quantize {quantizable:,d} parameters ({quantizable / total:.0%}) "
          f"and would save {saved_bytes / MB:.2f} MB against fp16.")
    print("Can't be quantized:")
    for reason, (tensors, count) in sorted(blocked.items(), key=lambda item: -item[1][1]):
        print(f"  {count:12,d} parameters in {tensors:3d} tensors ({count / total:.0%}): {reason}")
    print("Quantizable tensors (fp16 bytes -> 8-bit bytes, max abs round-trip error):")
    for key, shape, before, after, error in sorted(rows, key=lambda row: -row[2]):
        print(f"  {key:60s} {str(tuple(shape)):14s} {before:10,d} -> {after:10,d}  err {error:.5f}")


def check_checksums(files, update):
    actual = {path.name: sha256(path) for path in files}
    if update:
        CHECKSUMS.write_text("".join(f"{digest}  {name}\n" for name, digest in sorted(actual.items())))
        print(f"\nwrote {CHECKSUMS.name}")
        return
    if not CHECKSUMS.exists():
        fail(f"{CHECKSUMS.name} is missing: run with --update-checksums once and commit it")
    expected = dict(line.split()[::-1] for line in CHECKSUMS.read_text().splitlines() if line.strip())
    for name, digest in actual.items():
        if expected.get(name) != digest:
            fail(f"{name} does not match {CHECKSUMS.name} (if the change is on purpose: make update-checksums)")
    print(f"\nchecksums match {CHECKSUMS.name}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--update-checksums", action="store_true", help="rewrite assets.sha256 from the outputs")
    args = parser.parse_args()

    weights_path = CACHE / "kokoro-v1_0.safetensors"
    voices_path = CACHE / "voices.npz"
    CACHE.mkdir(exist_ok=True)
    download(WEIGHTS_URL, weights_path, lambda p: sha256(p) == WEIGHTS_SHA256)
    download(VOICES_URL, voices_path, lambda p: git_blob_hash(p) == VOICES_GIT_BLOB)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    sprout_path = OUTPUT / "sprout.safetensors"
    f16_path = OUTPUT / "kokoro-f16.safetensors"

    heart, nicole, sprout = make_sprout(voices_path)
    mx.save_safetensors(str(sprout_path), {"sprout": mx.array(sprout)})
    worst_blend = check_sprout(sprout_path, heart, nicole)

    original = mx.load(str(weights_path))
    weights, folded_count = fold_weight_norm(original)
    check_fold(original, weights, folded_count)
    converted = {key: array.astype(mx.float16) if is_float(array) else array for key, array in weights.items()}
    mx.save_safetensors(str(f16_path), converted)
    # Only for the folded-vs-unfolded test in PlantKokoroTests. Never shipped.
    unfolded_path = CACHE / "kokoro-f16-unfolded.safetensors"
    mx.save_safetensors(str(unfolded_path), {key: array.astype(mx.float16) if is_float(array) else array for key, array in original.items()})
    worst_fp16 = check_fp16(weights, mx.load(str(f16_path)))

    print(f"sprout: 0.45*heart + 0.55*nicole holds on all {sprout.size:,d} values (worst difference {worst_blend:.2e})")
    print(f"weight norm: folded {folded_count} convolutions into one weight each")
    print(f"fp16: {len(weights)} tensors round-trip within fp16 precision (worst absolute difference {worst_fp16:.2e})")
    report(weights, f16_path, sprout_path)
    check_checksums([sprout_path, f16_path], args.update_checksums)


if __name__ == "__main__":
    main()
