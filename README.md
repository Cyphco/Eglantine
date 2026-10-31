<!--
# SPDX-FileCopyrightText: Copyright 2025 Eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

# SPDX-FileCopyrightText: 2018 yuzu Emulator Project
# SPDX-License-Identifier: GPL-2.0-or-later
-->
<!-- lang: en-GB -->

<h1 align="center">
  <br>
  <a href="https://git.eden-emu.dev/eden-emu/eden"><img src="https://github.com/user-attachments/assets/35031845-4bfa-4916-8bf5-bc3bce67d5e2" alt="Eglantine" width="200"></a>
  <br>
  <b>Eglantine — Fire Emblem build</b>
  <br>
</h1>

<h4 align="center">A specialised fork of <a href="https://github.com/Djihads80/Eglantine">Eglantine</a> that gets <b>Fire Emblem</b> (Switch 2, title ID <code>04007EF01F8AE000</code>) running.
Eglantine is a free and opensource (FOSS) Switch 2 emulator, derived from Eden, Yuzu and Sudachi - started by developer Camille LaVey.
</h4>

> [!IMPORTANT]
> **This is not the official Eglantine.** It targets one game, Fire Emblem, and its changes are tuned for it
> (some, like the bank 24 identity matrix and the post-process constant patch, are workarounds rather than
> general fixes). For other games use [upstream Eglantine](https://github.com/Djihads80/Eglantine).
> Please don't report problems with this build upstream.

## Fire Emblem

### Status

| | |
|---|---|
| Boots, audio, menus, name entry | Working |
| Story scenes and gameplay | Working, correct colours |
| Tutorial battlefield | Loads; one draw is skipped to avoid a host GPU reset, so some battlefield graphics are missing |
| Image sharpness | Soft: the game's neural-network upscaler (tensor-core compute) only partly runs |

### Running it

Build the command-line emulator with `build-cli.bat` (Windows, Visual Studio 2022 with C++ and CMake), then:

```bat
run-fire-emblem.bat "C:\path\to\Fire Emblem\exefs\main"
```

You need your own dump of the game. The launcher sets the environment variables the game needs:

| Variable | Why |
|---|---|
| `EDEN_NX2_TENSOR=1` | Tensor-core (HMMA) emulation for the game's compute shaders |
| `EDEN_NX2_BINDLESS_FALLBACK=1` | Textures whose handles come from memory sample grey instead of rejecting the shader |
| `EDEN_NX2_NAN_CONSTANT_FIX=1` | Patches NaN post-process constants and the zero HDR paper white that blank the frame |
| `EDEN_NX2_CROP_WIDTH/HEIGHT=1280/720` | The game draws 1280×720 into the corner of a 3840×2160 window |
| `EDEN_NX2_SKIP_PS_HASH=c25f0c0e843817af` | Skips the battlefield draw that resets the host GPU |

After updating this build, delete or rename `%APPDATA%\eden\cache\shader\04007ef01f8ae000\vulkan.bin`: it holds
translated shaders from the previous build.

### What this fork changes

- **Services:** the nx2 `gsv`/`vi2`/`gpu`/`syncpt` handlers the game calls, AM additions, Switch 2 library applet IDs
  (the software keyboard at name entry), audio renderer revision 16, GPU characteristics flags.
- **Presentation:** HDR10 (A2B10G10R10) window images are shown in their own format, and found through any of the
  device addresses their memory is mapped at.
- **Shader translation (Ampere → Maxwell):** many new instruction forms, including 64-bit integer math, bindless
  textures across descriptor banks, uniform-register handles, texture queries and gradient sampling.
- **Bank 24:** the game's deferred lighting reads a normal-rotation matrix from constant bank 24, which nothing binds;
  it reads as an identity matrix (`EDEN_NX2_BANK24_ZERO=1` restores zeros).

### Known issues

- One battlefield draw (pixel shader hash `c25f0c0e843817af`) still resets the host GPU when not skipped. The fault is
  in one texture fetch of that shader, which samples a 512×512 BC3 texture; the cause isn't found yet.
- Two neural-network upscaler kernels can't be translated yet, so the 640×360 render is upscaled softly.
- The post-process constants come from a display brightness value the game reads as 0; the patch replaces them with
  fixed values, so exposure and HDR brightness aren't the game's own.

<p align="center">
    </a>
    <a href="https://discord.gg/jCCZ58VExk">
        <img src="https://img.shields.io/discord/1367654015269339267?color=5865F2&label=Eglantine&logo=discord&logoColor=white"
            alt="Discord">
    </a>
  
</p>

<p align="center">
  <a href="#fire-emblem">Fire Emblem</a> |
  <a href="#compatibility">Compatibility</a> |
  <a href="#development">Development</a> |
  <a href="#building">Building</a> |
  <a href="#download">Download</a> |
  <a href="#support">Support</a> |
  <a href="#license">License</a>
</p>

## Upstream Eglantine

The rest of this README is upstream's. This fork has no releases; for builds of the general emulator see upstream.

## Compatibility

The emulator is capable of running Mario Kart World at decent/full speed depending on specs and configurations, and Splatoon Raiders at variable performances

A list of supported games will be available in future. Please be patient.

## Development
For development discussions, please join us on [Discord](https://discord.gg/jCCZ58VExk)

If you would like to contribute, we are open to new developers and pull requests. Please ensure that your work is of a high standard and properly documented. You can also contact any of the developers on Discord or Stoat to learn more about the current state of the emulator.

## Documentation

We have a user manual! See our [User Handbook](./docs/user/README.md).

## Building

See the [General Build Guide](docs/Build.md)

For information on provided development tooling, see the [Tools directory](./tools)

## Download

You can download the latest releases from [here](https://github.com/Djihads80/Eglantine/releases).

## Support

We currently do not take in any donations for the time being

If you would prefer to support us in a different way, please join our [Discord](https://discord.gg/jCCZ58VExk)

## License

Eglantine is licensed under the GPLv3 (or any later version). Refer to the [LICENSE.txt](https://github.com/Djihads80/Eglantine/blob/nx2/LICENSE.txt) file.
