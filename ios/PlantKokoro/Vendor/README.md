# Vendor

Plain targets of the PlantKokoro package (docs/plans/M5c-kokoro.md, section 4). Copied from the
patched spike code (since deleted in K12), then trimmed.

| Target | Upstream | Commit | License |
|---|---|---|---|
| `KokoroSwift` | https://github.com/mlalma/kokoro-ios (1.0.11) | `4d6d1d8ff8cd012014180c9cd4cf0151e7682354` | MIT, see `KokoroSwift/LICENSE` |
| `MisakiSwift` | https://github.com/mlalma/MisakiSwift (1.0.6) | `6835a1ce4a8854075c89f18ff75c74b13ef58e15` | Apache-2.0, see `MisakiSwift/LICENSE` |

`MisakiSwift/Sources/MisakiSwift/Extensions/MToken.swift` is copied from
https://github.com/mlalma/MLXUtilsLibrary (Apache-2.0, version 0.0.6).

## Our changes

Both (from the spike patches):

- mlx-swift 0.30.6 instead of 0.30.2 (A18/A19 fixes, iOS 26 link errors).
- Resource bundles flattened so they pass codesign.

Added for PlantKokoro:

- Package manifests removed; the targets are declared in `ios/PlantKokoro/Package.swift`.
- MLXUtilsLibrary (and ZIPFoundation) dropped: `BenchmarkTimer` calls removed, `MToken` copied in.
  `NpyzReader` is not needed (the voice is a safetensors file).
- KokoroSwift: eSpeakNG processor and `G2P.eSpeakNG` removed; `.enGB` throws unsupported.
- MisakiSwift: British dictionaries (`gb_*`) removed. Only `us_gold`, `us_silver` and `us_bart`
  ship. `EnglishG2P(british: true)` would fail to load them, so don't use it.
- Tests and upstream READMEs not copied.
- Weight norm folded at build time (M5c K10): `ConvWeighted` takes one `weight` and does no norm math;
  `WeightLoader` applies its `weight_v` transposition rule to that `weight`. The weights file must come
  from `tools/kokoro` (`weight_g` / `weight_v` pairs are gone from it).

fp16 weights load as they are (`MLX.loadArrays` keeps fp16; the smoke test passes), so
`WeightLoader` is unchanged.
