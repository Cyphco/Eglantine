# Fire Emblem (04007EF01F8AE000) on nx2: boot fixes and the black-screen blocker

Branch `fe-gsv-port`, based on `nx2` at `b7a816a`. Tested with `eden-cli` (Windows, MSVC, Vulkan, RTX 3090) on a self-dumped copy of the game. Nothing is committed yet.

## Status

| Area | Before | Now |
|---|---|---|
| Boot | Userspace panic about 10 s in (null reads in subsdk1 device teardown) | Runs, steady 60 FPS, no panics |
| Audio | Aborted with 2153-1537 | Plays (REV16 treated as REV15) |
| Shaders translated (of all captured programs) | 65 of 81 | 219 of 243 |
| Failing compute dispatches per run | 43 | 13 |
| Picture | Black | Still black (see the blocker below) |

## The blocker: runtime bindless textures

The game's frame is a chain of 640x360 and 1280x720 render passes, and its last step copies a 1280x720 picture into the 3840x2160 window image. Presentation works: with `EDEN_NATIVE_FRAME_CAPTURE` the presenter finds the rendered window image on every frame. The window is black because the picture is black, and the picture is black because one early pass, the main material shader (pixel shader `0x19a21a2200`, 156 texture samples, drawing to a 640x360 RGBA16F target), is rejected and its draw skipped.

Its texture handles are loaded from GPU memory at run time (nvdisasm, SM86):

```
/*8580*/  IADD3 R100, R108, 0x98, RZ ;
/*85c0*/  LDG.E.64.CONSTANT R100, [R100.U32+UR4] ;
/*8700*/  ISETP.NE.U32.AND P0, PT, R100, RZ, PT ;
/*8730*/  ISETP.NE.U32.AND.EX P0, PT, R101, RZ, PT, P0 ;
...
/*8ad0*/  MOV R43, R100 ;
/*8d10*/  TEX.SCR.B.NODEP RZ, R112, R40, R42, CUBE, 0x1 ;   // handle = R43, the register after Rb's coordinates
```

`ir_opt/texture_pass.cpp` (`MakeInst`) only accepts bindless handles it can trace back to a constant buffer and otherwise throws `Failed to track bindless texture constant buffer`. PR #27's `0x361` lowering works for Kirby because its handles come from uniforms or constants; these do not. Sampling these textures needs runtime bindless support (indexing the guest texture descriptor pool at draw time), which touches the shader backend, Vulkan descriptor setup and the texture cache.

The same shader also needs translator work regardless of the above: `TEX.SCR.B` with cube, AOFFI, LZ and LL forms, `TEX.B.LL`, `TXQ.B`, a few `TEX.SCR.LZ` forms, and one `TLD.SCR.LZ` from descriptor bank 7 while the rest of the shader uses bank 4.

## Fixes in this branch

"Verified" means the effect was observed in the game (a crash or error went away, a call now succeeds). "Accepted only" means the translator now lowers the instruction, but nothing renders yet that would show a wrong result.

### Services and drivers (verified)

- **GPU engine flags** (`nvhost_ctrl_gpu.cpp`): set `NVGPU_GPU_FLAGS_SUPPORT_2D/3D/COMPUTE/I2M/ZBC` (bits 40-44). Newer NvRm (`sdk 0x626ca0`) adds the 2D, 3D and compute classes to a device's class list only when these are set. Without them its GPU object had no 3D or compute class, the CUDA-style driver in subsdk1 failed its supported-chip check (`subsdk1 0x19ad20`) with NO_DEVICE, and the program aborted while tearing the device down. This is probably why other Switch 2 titles ask for object class 0 (see the comment in `nvhost_gpu.cpp`).
- **Audio renderer REV16** (`audio_core/common/feature_support.h`): accepted and treated as REV15. Unverified beyond "audio plays". There is also a log line naming any unsupported revision a game asks for.
- **`VSMS_MAPPING` ioctl** (ctrl-gpu 0x13): answers Switch 2 callers instead of returning NotImplemented.
- **nx2:gsv / vi2 / gpu / syncpt handlers** (`nx2_gsv.h`): 23 calls this title makes, with reply shapes taken from PR #2: gsv 11, 115, 126, 201, 301, 401, 402, 434, 1101, 1102, 1501, 1502; vi2 51, 101, 111, 201, 212, 251, 269 and a quiet 106 (called every frame, which used to flood the log); gpu 41/42 (`CreateGraphicsDevice`); syncpt 21. Plus `ISelfController` 2400 and `IGraphicsScaleController` 1050.
- **`eden-cli -d <port>`** (`launch_params.cpp`): `-d` was declared without an argument but read one, so it crashed on start.
- **Stack spills** (`lower_to_maxwell.h`, `shader_environment.cpp`): `LDL`/`STL` through `R1 = c[0x0][0x28] - frame` read zeros, because the native stack sits under a top of about `0xfffdc0` and Eden returns 0 beyond the program's small local size. Register-addressed accesses are now rebased into a 1 KiB window, and the environment raises `local_memory_size` to cover it.
- **Native QMD failures**: the raw `words=` dump moved to debug level.

### Ampere-to-Maxwell lowering (accepted only)

All in `shader_recompiler/frontend/ampere/lower_to_maxwell.h`, decoded with nvdisasm where the encoding was not obvious:

- `HFMA2.RELU` predicate operand (bits 87-89, negate 90): the clamp applies only where the predicate is true. The game sets it from a constant-buffer flag; PT is the old always-clamp case.
- `ISETP.EX` (64-bit compare chaining the low result from bits 68-70).
- `IDP.2A.LO.U16.U8` (2D offsets from two 16-bit strides).
- `IMAD.HI` from a constant and the signed form; `IMAD.WIDE` with a 64-bit constant addend; `IMAD.X` carry-in.
- `IADD3`: carry-out with a uniform operand, two carry-outs with a third source, and the general `.X` with two carry-ins.
- `LEA`: low with carry-out, uniform base, and `LEA.HI(.X)` with sign extension or a third register.
- `SHF.R.HI` with a constant-buffer amount; `USHF` for UR16-UR27.
- `REDUX` AND/OR/XOR/MIN/MAX; `MATCH.ALL.U32`; `ATOMS` with every operation; `BAR.SYNC.DEFER_BLOCKING`.
- `TXQ` from any descriptor bank.
- `SULD`/`SUST` from a second descriptor bank, via an LDC-loaded handle and the bindless form.
- `MUFU.TANH` (computed with EX2/RCP); `MUFU` with a uniform source.
- `HSET2.EQU |x|, INF` as an integer mask.
- `F2I` truncation without FTZ; `FMNMX` with bit 81 (taken as `.NAN`).
- Cache-hint bits on `LDG`, `STG` and `SUST`; `IMNMX` with a negative immediate.

### Removed experiments

Reporting compute class 0xC9C0 and a framebuffer-format change in the texture cache did not help and were reverted.

## Tools that made this possible

- **Offline scanner**: dump every captured program with `EDEN_NX2_SHADER_DUMP=<dir>`, then run `LowerToMaxwell` over all of them. For each rejected instruction it sets the predicate to `@!PT` and lowers again, so every gap in a program is listed in one pass, not only the first. Decode each gap with `nvdisasm -b SM86 <raw instruction file>`.
- **`EDEN_NX2_DUMP_PRESENT=<n>`** (`nx2_gsv.h`): dumps the presented image's memory at present n.
- **Existing switches** used: `EDEN_NX2_WINDOW_TRACE`, `EDEN_NX2_RT_TRACE`, `EDEN_NATIVE_FRAME_CAPTURE`, `EDEN_NX2_IPC_TRACE`, and the GDB stub (with LLDB from the Android NDK) for frame walks at the crash site.

## Remaining shader gaps (9 unique programs)

- **Tensor cores**: `HMMA.1688.F16` and `HMMA.16816.F16` forms not covered by `EDEN_NX2_TENSOR`, and `LDSM`.
- **Scratch-register clash**: one large compute kernel uses R216-R249, which the lowering reserves for scratch and uniform registers.
- **Async copies**: `LDGSTS`, `LDGDEPBAR`, `DEPBAR`.
- **Integer**: 64-bit `IMAD.HI.U32`/`IMAD.WIDE.U32` register forms, `IADD3` with negated operands, `F2I.U64`/`I2F.U64`.
- **Other**: `CALL.REL.NOINC`, `LDC.U8`, `BPT.TRAP`.
- **The material shader's texture forms**, listed above.

## Before merging anything

- Remove the three `TEMP-FE-TRACE` blocks in `renderer_vulkan/vk_rasterizer.cpp`.
- Add unit tests under `src/tests/video_core` for the new lowerings. None of them have tests yet.
- `EDEN_NX2_TENSOR=1` is still needed for this title.
