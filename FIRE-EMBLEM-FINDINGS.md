# Fire Emblem (Switch 2) on Eglantine nx2: findings

Title `04007EF01F8AE000`. Worktree `Eglantine-nx2`, branch `fe-gsv-port` (based on `nx2` `b7a816a`). Nothing is committed yet.

## Update: black screen fixed (pending confirmation on screen)

The black screen had three causes, none of them the upscaler:

1. **NaN constants:** the game's post-process constants (exposure, tonemap white point, UI fade) arrive as NaN. `EDEN_NX2_NAN_CONSTANT_FIX` replaces NaN in the pixel stage's `c[3]` with 1.0. The source of the NaNs is probably the auto-exposure compute shader at `0x19a2cda000`, which is rejected for 64-bit integer math (`F2I.U64`/`I2F.U64`).
2. **Zero paper white:** the HDR10 window pass scales by paper-white nits (`c[3][0x2c]`), which is 0. The same switch sets it to 100.
3. **Wrong window format:** the presenter looked the window up as RGBA8 and showed an empty alias of it. The texture cache now presents the A2B10G10R10 render target in its own format.

The game also draws 1280×720 into the corner of a 3840×2160 image, so `run-fire-emblem.bat` sets `EDEN_NX2_CROP_WIDTH/HEIGHT=1280/720`. The output is PQ-encoded HDR shown as-is, so it looks dim. Tone-mapping it back to SDR in the presenter is the next improvement.

## Where it stood before the update

- **Working:** boot, audio, all services the game calls, presentation, and the 3D/material/UI passes. Host render-target dumps show real scene data in `0x810874a000`, `0x8110773000`, `0x8110863000`, and in the UI target `0x8111f59000`.
- **Still black:** the 1280×720 B10G11R11F targets `0x8112319000` and `0x8105fa0000` (the final source) are uniformly `0xffffffff`, which is NaN. That NaN carries through into the 3840×2160 A2B10G10R10 window, so the screen is black.
- **Cause:** the game upscales with a neural network that runs on tensor cores (`HMMA`, `LDSM`, `LDGSTS`). Those compute kernels don't lower to Maxwell yet, so they never run and their outputs stay uninitialised. The bloom and composite shaders after them are NaN-safe, so the problem starts at the network.

## Fixed so far

| Area | Fix |
|---|---|
| Services | 23 nx2 handlers ported (gsv, vi2, gpu, syncpt), plus AM 2400/1050 |
| GPU driver | ctrl-gpu flags bits 40–44, ioctl 0x13 VSMS mapping |
| Audio | renderer revision 16 |
| Shader translator | dozens of SM86 forms: IMAD.HI/WIDE/X, LEA variants, REDUX, ATOMS, HSET2, IDP, MUFU.TANH, HFMA2.RELU, ISETP.EX, stack-spill rebasing, HMMA.1688, and more |
| Bindless textures | TEX/TLD/TXQ/SULD/SUST bindless lowering. Handles that can't be traced fall back to grey (`EDEN_NX2_BINDLESS_FALLBACK=1`) |
| Uniform registers | the UR base register is now chosen per shader, above the shader's highest register (previously fixed at R216) |
| IMAD.WIDE | register (`225`) and immediate (`825`) multiplier forms with a register-pair addend |

Offline scan of the 81 compute shaders dumped from a run: **76 lower, 5 don't** (up from 75).

## The 5 shaders that still don't lower

| Shader | Role | Blocker |
|---|---|---|
| `9638d757` | upscaler | uses registers up to R252 and so collides with the lowering scratch registers; needs spilling or a scratch remap. Also uniform-address LDG/STG, `LDSM` |
| `9f56b9c8` | upscaler | `LDGSTS` (async copy), `LDGDEPBAR`, `DEPBAR`, `LDSM` with a UR offset |
| `7e1364b3` | other | 64-bit integer math (`F2I.U64`, `I2F.U64`, IADD3 carry chains, IMAD.HI) |
| `4cbf6eff` | other | `CALL.REL.NOINC` (subroutine calls) |
| `966b6ea1` | other | `BPT.TRAP`, `LDC.U8` |

The two upscaler kernels are what's needed for a picture. They're the hard part: `9638d757` needs register pressure relieved, and `9f56b9c8` needs async global→shared copies emulated as plain loads and stores.

## Workaround worth trying

If the network can't be lowered soon, the practical route to an image is to skip it: detect the upscaler dispatches and substitute a plain bilinear upscale (640×360 → 1280×720) into its output targets. That gives a softer picture but a playable one.

## Tooling

- Env vars:
  - `EDEN_NX2_SHADER_DUMP`: dumps shaders
  - `EDEN_NX2_DUMP_RT="<frame>,<addr>,..."` with `EDEN_NX2_FRAME_CAPTURE=<dir>`: host render-target dumps
  - `EDEN_NX2_DUMP_PRESENT`: dumps the presented image
- Offline scanner: `Eglantine-fe-debug\scan\scan.exe <dump dir> [-v]`. `decode_gaps.py` decodes each gap with `nvdisasm -b SM86`.
- Launch: `run-fire-emblem.bat` (sets `EDEN_NX2_TENSOR=1`, `EDEN_NX2_BINDLESS_FALLBACK=1`).
- Before committing: remove the `TEMP-FE-TRACE` debug code in `vk_rasterizer.cpp`, `texture_cache.h` and `texture_cache_base.h`, and add unit tests.

Longer write-up: `FIRE-EMBLEM-NX2-NOTES.md`.
