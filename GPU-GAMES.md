# Games for Cubie A7Z (ARM64 / PowerVR BXM-4-64 / 1 GB RAM)

**Baseline reference:** Yamagi Quake II -- 60 fps GLES3 KMSDRM, 67 fps Vulkan X11.

**GPU context:** PowerVR BXM-4-64 MC1 scores ~468 in 3DMark Wild Life -- comparable
to Mali-G52 MP1, well below Adreno 619.  Supports GLES 3.2, Vulkan 1.3, OpenCL 3.0.

**Hard constraint:** 1 GB total RAM.  After OS + Xorg/Wayland expect ~650-700 MB free.
Games above ~500 MB RSS are risky.  Swap on 25 MB/s microSD is almost useless.

---

## TIER 1 -- HIGH CONFIDENCE (will run, similar or better than Q2)

### 1. Quake III Arena -- ioquake3 / Q3lite
- **Engine:** ioquake3 (OpenGL 2.x) or Q3lite (OpenGL ES native)
- **RAM:** ~80-120 MB
- **Debian pkg:** `ioquake3` in Trixie arm64, `quakespasm` also available
- **Renderer:** ioquake3 = OpenGL (needs gl4es or native GL); Q3lite = native GLES
- **Performance:** Should exceed Q2 fps; simpler geometry.  1080p easily.
- **Game data:** Shareware demo pak0.pk3 free; full game requires purchase or Q3A CD
- **Build:** `apt install ioquake3` or compile Q3lite from github.com/cdev-tux/q3lite
- **Verdict:** GUARANTEED TO WORK.  Compile Q3lite for best native GLES path.

### 2. Quake 1 -- QuakeSpasm
- **Engine:** QuakeSpasm (OpenGL 1.x/2.x), uses SDL2
- **RAM:** ~50-80 MB
- **Debian pkg:** `quakespasm` in Trixie arm64
- **Renderer:** OpenGL (works via gl4es or PVR desktop GL)
- **Performance:** Extremely lightweight. 1080p 60+ fps trivial.
- **Game data:** Shareware episode free (id1/pak0.pak); full requires purchase
- **Build:** `apt install quakespasm`
- **Verdict:** GUARANTEED TO WORK.

### 3. Chocolate Doom / Crispy Doom + Freedoom
- **Engine:** Chocolate Doom (vanilla faithful) / Crispy Doom (enhanced limits)
- **RAM:** ~30-60 MB (software renderer, extremely light)
- **Debian pkg:** `chocolate-doom`, `crispy-doom`, `freedoom-data` -- all in Trixie arm64
- **Renderer:** Software (SDL2 surface). No GPU needed.
- **Performance:** 1080p 60fps, trivial.
- **Game data:** `freedoom-data` is 100% free replacement WADs; or use shareware DOOM1.WAD
- **Build:** `apt install crispy-doom freedoom-data`
- **Caveat:** Software-rendered only, visually faithful to 1993.  Qualifies as
  "Quake II level" only if you count gameplay depth, not graphics fidelity.
- **Verdict:** GUARANTEED TO WORK.  Not a graphical showcase but rock solid.

### 4. DXX-Rebirth (Descent 1 & 2)
- **Engine:** DXX-Rebirth, supports OpenGL and OpenGL ES natively
- **RAM:** ~60-100 MB
- **Debian pkg:** Not in Trixie arm64; compile from source (scons `opengles=1`)
- **Renderer:** Native OpenGL ES via `opengles=1` build flag
- **Performance:** Lightweight 1997-era engine. 1080p 60fps easy.
- **Game data:** Shareware D1 levels free; full game on GOG/Steam cheap
- **Build:** github.com/dxx-rebirth/dxx-rebirth -- `scons opengl=0 opengles=1`
- **Verdict:** GUARANTEED TO WORK.  True 6DOF shooter, excellent game.

### 5. Serious Sam Classic (First/Second Encounter)
- **Engine:** Open-source Serious Engine 1 (tx00100xt fork)
- **RAM:** ~150-250 MB (some large levels need 300+; delete KarnakDemo.wld if tight)
- **Debian pkg:** Not in Debian. Compile from source.
- **Renderer:** OpenGL (1.x/2.x). Vulkan version also exists (SeriousSamClassic-VK).
- **Performance:** Runs on Raspberry Pi 4 (weaker GPU). Pi-specific cmake flag `-DRPI4=TRUE`.
  Expect 30-60 fps at 720p-1080p depending on level complexity.
- **Game data:** Free demo levels included; full game data from GOG/Steam (~$1-5 on sale)
- **Build:** github.com/tx00100xt/SeriousSamClassic -- cmake + make
- **Caveat:** Some large levels may OOM on 1GB. Delete oversized demo maps.
- **Verdict:** HIGH CONFIDENCE.  Proven on Pi 4.  Watch RAM on big levels.

### 6. Xash3D FWGS (Half-Life 1)
- **Engine:** Xash3D FWGS -- full GoldSrc reimplementation
- **RAM:** ~100-200 MB
- **Debian pkg:** Not in Debian. Compile from source.
- **Renderer:** Native OpenGL, GLESv1, GLESv2 -- all supported!
- **Performance:** Originally targets Android phones.  ARM64+GLES is primary platform.
  1080p 60fps expected.
- **Game data:** Requires Half-Life game files (Steam purchase, ~$10). No free alternative.
- **Build:** github.com/FWGS/xash3d-fwgs -- `./waf configure && ./waf build`
- **Verdict:** HIGH CONFIDENCE.  Engine literally designed for ARM+GLES.

---

## TIER 2 -- LIKELY WORKS (may need tuning / lower resolution)

### 7. GZDoom + Freedoom / Brutal Doom
- **Engine:** GZDoom (modern Doom engine, advanced scripting/rendering)
- **RAM:** ~200-400 MB base; mods like Brutal Doom v22 add more.
  Project Brutality WILL NOT run (too heavy even on Pi 5).
- **Debian pkg:** Not in Trixie arm64. Compile from source or use RaspZDoom fork.
- **Renderer:** OpenGL ES (not officially supported but works on Pi 5),
  Vulkan NOT working on ARM PowerVR currently.
- **Performance:** Brutal Doom v22 runs on Pi 5 (4x A76 @ 2.4GHz).
  Your board has 2x A76 @ 2.0GHz -- slower, but same architecture.
  Expect 30-50 fps at 1080p with vanilla Doom, less with heavy mods.
- **Game data:** `freedoom-data` (free) or purchased WADs
- **Build:** github.com/ZDoom/gzdoom or github.com/madame-rachelle/RaspZDoom
- **Caveat:** Shader compilation eats RAM temporarily. 1GB is tight for GZDoom+mods.
- **Verdict:** LIKELY WORKS for vanilla GZDoom.  Avoid heavy mods.

### 8. EDuke32 (Duke Nukem 3D)
- **Engine:** EDuke32 Build engine port
- **RAM:** ~80-150 MB
- **Debian pkg:** Not in Trixie arm64. Compile from source.
- **Renderer:** OpenGL (Polymost), software (classic). No native GLES.
- **Performance:** Build engine is lightweight. Should run well.
- **Game data:** Shareware GRP free (1 episode); full game on GOG/Steam
- **Build:** eduke32.com source -- `make` (may need tweaks for aarch64)
- **Caveat:** ARM64 not officially tested. Gentoo has arm64 keyword.
  May need gl4es for GLES translation.
- **Verdict:** LIKELY WORKS with some build effort.

### 9. SuperTuxKart
- **Engine:** Custom engine, Antarctica renderer
- **RAM:** ~300-500 MB (with textures loaded). 1GB total is very tight.
- **Debian pkg:** `supertuxkart` in Trixie arm64!  Easy install.
- **Renderer:** OpenGL 3.x (full pipeline) or GLES 2.x/3.x (fallback pipeline).
  Vulkan beta available in v1.5+.
- **Performance:** Disable "Advanced Pipeline" for huge fps gain.
  720p + low textures likely needed for 1GB.  Mobile version runs on 1GB phones.
- **Game data:** 100% free and open source.  All data included.
- **Build:** `apt install supertuxkart` or compile for newer version
- **Caveat:** RAM is the main concern.  May OOM on complex tracks with advanced pipeline.
  Reduce texture quality.  Consider 720p render resolution.
- **Verdict:** LIKELY WORKS at low settings.  Test carefully.

### 10. PPSSPP (PSP Emulator)
- **Engine:** PPSSPP emulator with ARM64 JIT
- **RAM:** ~150-300 MB depending on game
- **Debian pkg:** Not in Trixie arm64. Compile from source.
- **Renderer:** OpenGL ES 2.0+, Vulkan -- both supported natively
- **Performance:** ARM64 JIT is highly optimized (primary Android platform).
  God of War, GTA, Tekken 6 etc. at PSP resolution (480x272) scaled 2x.
  BXM-4-64 with Vulkan should handle most PSP games.
- **Game data:** PSP game ISOs (own your games). Many free homebrew.
- **Build:** github.com/hrydgard/ppsspp -- cmake + make
- **Caveat:** Some GPU-heavy PSP games (GoW) may struggle. Start at 1x resolution.
  RAM OK for most games; avoid memory-heavy RPGs.
- **Verdict:** LIKELY WORKS.  Opens up huge PSP library.  Excellent value.

### 11. Flycast (Dreamcast/Naomi Emulator)
- **Engine:** Flycast, fork of reicast
- **RAM:** ~100-200 MB
- **Debian pkg:** Not in Trixie. Compile from source.
- **Renderer:** OpenGL ES, Vulkan -- both supported
- **Performance:** Dreamcast had simple GPU.  ARM64+GLES is primary target (Android).
  Soul Calibur, Crazy Taxi, Jet Set Radio at native 640x480 scaled up.
- **Game data:** Dreamcast GDI/CHD images (own your games).
- **Build:** github.com/flyinghead/flycast -- cmake
- **Caveat:** Some Naomi games heavier.  Stick to Dreamcast titles.
- **Verdict:** LIKELY WORKS.  Another large game library opened up.

### 12. DarkPlaces / Xonotic (Quake-based FPS)
- **Engine:** DarkPlaces (enhanced Quake engine)
- **RAM:** Engine ~100 MB, but Xonotic data adds ~300-500 MB textures
- **Debian pkg:** `darkplaces` in Trixie arm64 (engine only)
- **Renderer:** OpenGL 3.2 or OpenGL ES 2.0
- **Performance:** Xonotic server is reported 10x heavier than Q3 on ARM.
  The client is also demanding with modern effects.
- **Game data:** Xonotic is 100% free. DarkPlaces can play Quake maps.
- **Build:** `apt install darkplaces` + download Quake shareware data
- **Caveat:** Xonotic is heavy for 1GB.  Plain DarkPlaces + Quake data is fine.
- **Verdict:** LIKELY WORKS for DarkPlaces+Quake.  Xonotic risky (RAM).

---

## TIER 3 -- RISKY (may not fit in 1 GB or have ARM64 issues)

### 13. OpenMW (Morrowind)
- **Engine:** OpenMW -- full Morrowind reimplementation using OpenSceneGraph
- **RAM:** ~400-600 MB minimum. Morrowind data itself is ~1 GB on disk.
- **Debian pkg:** `openmw` in sid arm64 (not trixie yet)
- **Renderer:** OpenGL (desktop). NO native GLES -- needs gl4es translation.
- **Performance:** Needs significant settings reduction: low view distance, low shadow res,
  high object paging min size.  720p or lower.
- **Game data:** Requires Morrowind game files (GOG/Steam, ~$15).  No free alternative.
- **Build:** Compile from git with careful OSG+gl4es setup.
- **Caveat:** 1GB is below comfortable minimum.  Will swap.  May crash on large exteriors.
  gl4es translation layer adds overhead.
- **Verdict:** RISKY.  Technically possible but will be painful on 1GB.

### 14. Unreal Tournament (OldUnreal 469d)
- **Engine:** OldUnreal patch 469d -- native arm64 Linux binaries exist!
- **RAM:** ~200-400 MB
- **Debian pkg:** Not in Debian. Download binaries from oldunreal.com.
- **Renderer:** OpenGL.  May need gl4es.
- **Performance:** Proven on Raspberry Pi arm64.  Should be comparable to Q2/Q3 era.
- **Game data:** Requires UT99 GOTY (GOG/Steam, ~$10). No free alternative.
- **Build:** Pre-built arm64 binaries available!
- **Caveat:** OpenGL-only, no GLES.  Need to test gl4es compatibility with PVR driver.
- **Verdict:** RISKY due to gl4es requirement, but binaries exist.

### 15. 0 A.D. (RTS)
- **Engine:** Pyrogenesis (custom engine + SpiderMonkey JS)
- **RAM:** 1.5+ GB recommended.  Absolutely will not fit in 1GB.
- **Debian pkg:** `0ad` in Trixie arm64
- **Renderer:** OpenGL 2.x+
- **Game data:** 100% free and open source.
- **Verdict:** WILL NOT RUN on 1GB.  Do not attempt.

### 16. OpenRA (C&C / Red Alert)
- **Engine:** .NET/Mono runtime + custom engine
- **RAM:** ~500+ MB (Mono runtime is heavy)
- **Debian pkg:** Not in Trixie arm64.
- **Renderer:** OpenGL via .NET bindings
- **Game data:** Free -- includes C&C/RA game data
- **Caveat:** Mono/.NET runtime on ARM64 is memory-hungry.  500MB server alone.
- **Verdict:** VERY RISKY on 1GB.  Mono overhead likely pushes over limit.

### 17. PCSX2 / AetherSX2 (PS2)
- **RAM:** 2-4 GB minimum
- **Verdict:** IMPOSSIBLE on 1GB.  Do not attempt.

---

## TIER SUMMARY TABLE

| # | Game/Engine             | RAM (MB) | GLES/VK | Debian pkg | Data        | Confidence |
|---|-------------------------|----------|---------|------------|-------------|------------|
| 1 | Quake III (Q3lite)      | 80-120   | GLES    | ioquake3   | Shareware   | CERTAIN    |
| 2 | Quake 1 (QuakeSpasm)    | 50-80    | GL*     | quakespasm | Shareware   | CERTAIN    |
| 3 | Crispy Doom + Freedoom  | 30-60    | SW      | crispy-doom| Free        | CERTAIN    |
| 4 | Descent (DXX-Rebirth)   | 60-100   | GLES    | --         | Shareware   | CERTAIN    |
| 5 | Serious Sam Classic     | 150-300  | GL/VK   | --         | Demo+$      | HIGH       |
| 6 | Half-Life (Xash3D)      | 100-200  | GLES    | --         | $10         | HIGH       |
| 7 | GZDoom + mods           | 200-400  | GLES*   | --         | Free        | MEDIUM     |
| 8 | Duke3D (EDuke32)        | 80-150   | GL*     | --         | Shareware   | MEDIUM     |
| 9 | SuperTuxKart            | 300-500  | GLES/VK | stk        | Free        | MEDIUM     |
|10 | PPSSPP (PSP emu)        | 150-300  | GLES/VK | --         | Own games   | MEDIUM     |
|11 | Flycast (DC emu)        | 100-200  | GLES/VK | --         | Own games   | MEDIUM     |
|12 | DarkPlaces + Quake      | 100-200  | GLES    | darkplaces | Shareware   | MEDIUM     |
|13 | OpenMW (Morrowind)      | 400-600  | GL*     | sid only   | $15         | LOW        |
|14 | Unreal Tournament 99    | 200-400  | GL*     | --         | $10         | LOW        |
|15 | 0 A.D.                  | 1500+    | GL      | 0ad        | Free        | NO         |
|16 | OpenRA                  | 500+     | GL      | --         | Free        | VERY LOW   |
|17 | PCSX2 (PS2 emu)         | 2000+    | --      | --         | --          | NO         |

GL* = needs gl4es translation layer.  SW = software renderer.

---

## RECOMMENDED INSTALL ORDER (bang for the buck)

1. **apt install crispy-doom freedoom-data** -- instant gratification, 0 cost
2. **apt install quakespasm** + shareware pak0.pak -- classic Quake 1
3. **apt install ioquake3** or build Q3lite -- Quake 3 Arena
4. **Build Xash3D FWGS** -- if you own Half-Life, this is the best showcase
5. **Build DXX-Rebirth** with GLES -- Descent 1+2, shareware available
6. **Build Serious Sam Classic** -- impressive for an SBC, free demo
7. **Build PPSSPP** -- unlocks entire PSP library (God of War, Tekken, etc.)
8. **Build Flycast** -- Dreamcast: Soul Calibur, Crazy Taxi, Shenmue
9. **apt install supertuxkart** -- free racing, needs low settings

---

## NOTES ON gl4es

Many OpenGL-only engines need gl4es (github.com/ptitSeb/gl4es) to translate
desktop GL calls to GLES.  On PowerVR BXM-4-64:
- The PVR driver exposes both desktop GL and GLES contexts
- If desktop GL context works natively, gl4es is unnecessary
- If only GLES works, build gl4es and LD_PRELOAD it
- Test: `glxinfo | grep "OpenGL version"` -- if it shows 3.x+, native GL works

## NOTES ON VULKAN

PowerVR BXM-4-64 supports Vulkan 1.3 via pvr-mesa or proprietary driver.
Games with Vulkan renderers (vkQuake, PPSSPP, Flycast, Serious Sam VK,
SuperTuxKart 1.5) can potentially bypass GL entirely.  Test:
`vulkaninfo | grep deviceName` to confirm Vulkan is operational.
