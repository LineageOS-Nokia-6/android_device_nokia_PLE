# LineageOS 23.2 integration for Nokia 6 (PLE)

The Nokia implementation uses exactly three trees: `device/nokia/PLE`,
`vendor/nokia/PLE` and `kernel/nokia/msm8937`. No Nokia common or separate patch
repository is required. Platform projects are checked against their current
source contents; compatible upstream commits do not need to match the recorded
base revisions. This series targets LineageOS 23.2 and its manifest-selected CAF
branches/AOSP tags, not arbitrary future Android releases.

## Apply the remaining platform changes

From the Android source root:

```sh
./device/nokia/PLE/patches/apply.sh --source . --check
./device/nokia/PLE/patches/apply.sh --source .
```

The first command is optional: normal application performs the same preflight
for every project before the first write. The script requires Git and Python 3.9+.
It works from another directory when `--source` names the Android checkout.

The series contains **22 patches across 13 platform repositories**. The manifest
records the tested base commit as provenance, SHA256 and strip level of every patch;
0024 uses `-p3`, all others use `-p1`.

Preflight uses temporary Git indexes/object stores, not a platform checkout or
the source project's real index. It derives a baseline from current HEAD,
including unrelated committed upstream updates, and recognizes an exact applied
prefix or the complete applied series, including committed prefixes. A second
invocation is a no-op; an interrupted series resumes only from a known prefix.
Unrelated tracked/untracked edits, staged changes, unfinished Git operations,
missing source files/repositories, changed patches and conflicting source trees
are rejected. Ignored build outputs are left alone.

For exact recorded-baseline reproduction, add `--strict-base` to either command.
Only that optional mode requires the recorded base commit objects and tree
contents. Neither mode fetches them. Patch 0020 requires the header added by
0018; keep the declared order. Nokia stock ABI and product guards are retained
even when newer platform commits are accepted. Passing preflight does not replace
a full build and hardware regression tests.

Application changes working files only. It does **not** create commits, signoffs,
reset/clean repositories, fetch/sync sources, change branches, build images or
access a phone. Commit applied platform changes yourself if desired. On an I/O
failure or concurrent edit the script stops without destructive rollback;
inspect the error before resuming. It is not a cross-project atomic transaction.
Nothing is silently applied during envsetup, lunch or compilation.

## Fixes integrated directly into the device tree

| Former patches | Implementation now compiled from this device tree |
| --- | --- |
| 0011 | `../vibrator/`: honest legacy capabilities, timeout and error handling |
| 0013 | `../sensors/hal/`: publish only a nonempty real sensor list |
| 0015 | `../goodix/fingerprint/`: PLE/Goodix active-group compatibility |
| 0016, 0017 | `../radio/hidlbase/`: shared constructor maps and global ELF visibility |

These small source adapters retain their upstream licenses and the accepted
implementation bytes. Their unique Soong names end in `.ple`; `stem` retains
the installed executable/library names and existing RC/VINTF paths. In
particular, stock consumers still load `libhidlbase_shim.so`, not a renamed ABI.
The fingerprint adapter keeps its existing PLE module name and scoped CFI
exception. Product selection and the rild link dependency select local variants.
Keyboard35ms/system45ms haptics and all existing policy are unchanged.

Patches0025–0027 disable only the three superseded generic modules when
`nokia_ple.device_local_hal=true`, as selected by BoardConfig.mk. This is needed
before Soong emits Make install rules: `overrides` alone does not prevent two
globally visible modules with the same stem from creating conflicting rules.
The implementations remain entirely local. Other products retain the generic
modules by default; installed PLE paths, SONAMEs, init and policy stay unchanged.

## Why the other patches remain external

A device overlay supplies resources and configuration, not replacement C++,
Java or Kotlin method bodies in another repository. Copying a helper into a
device tree does not change its platform call sites. Soong source groups must
be exported from the package that owns the sources; `../` path escapes are not
a supported replacement. These patches avoid copying entire maintained stacks.

| Patch | Platform owner | Reason it stays |
| --- | --- | --- |
| 0001 | msm8998/display | Private Soong defaults must select modern ION ABI/dependencies |
| 0002 | Launcher3 | Taskbar code must consume the existing no-scrim resource |
| 0003 | lineage/interfaces camera | JPEG footer/fence conversion lives in CameraDeviceSession |
| 0004 | sdm660/media | Export source groups used by device-local codec modules |
| 0005 | msm8998/media | Suppress competing installers; library overrides alone do not cover dependency installs |
| 0006 | sdm660/media | Correct a compiler-rejected conditional without disabling diagnostics |
| 0007 | msm8998/display | Correct private gralloc CPU usage-mask interpretation |
| 0008 | Glimpse | Release/reacquire the Activity decoder at lifecycle boundaries |
| 0009 | frameworks/base | Battery glyph drawing is SystemUI Kotlin code, not an overlay resource |
| 0010 | lineage/interfaces power | Cancellation belongs to the maintained libperfmgr implementation |
| 0012 | system/sepolicy | Keep the actual host policy checker's full-width permission mask |
| 0014 | AudioFX | Service/backend lifecycle and null-key checks are application code |
| 0018 | hardware/ril | Normalize stock card records at the real libril callback |
| 0019 | lineage/interfaces radio | Preserve physical slot identity through the radio wrapper |
| 0020 | hardware/ril | Normalize the stock signal ABI before standard conversion |
| 0021 | frameworks/opt/telephony | Preserve SIM-record fallback when optional HAL ICCID is empty |
| 0022 | frameworks/opt/telephony | Handle asynchronous null profile IDs in the subscription service |
| 0023 | lineage/interfaces radio | Convert empty legacy data-call fields into zero HIDL tokens |
| 0024 | frameworks/base | Edge surfaces require changes to WindowManager transition call sites |
| 0025 | lineage/compat | Disable competing generic HIDL shim installer for the PLE-local implementation |
| 0026 | hardware/interfaces | Disable competing generic sensor service installer for PLE |
| 0027 | lineage/interfaces | Disable competing generic vibrator installer for PLE |

The five local fixes were removed from this queue; do not apply old copies as
additional generic platform modifications. Numbering is retained for traceable
source comparison; gaps in the series are intentional.

## Build inputs

The source kernel remains Linux4.19.325. Hardware data comes from exact Nokia
Android9 `00WW_6_19F`, not Xiaomi board data. Populate the private vendor payload
with `vendor/nokia/PLE/extract-files.sh` before building `lineage_PLE`; see that
repository's `README` for inputs and commands. The complete extraction includes
both hash-pinned PLE Wi-Fi files and checks all selected output digests/modes.
Do not substitute another device's firmware/configuration. This integration
does not itself claim a full clean build or a new device runtime qualification.

Patch0007 follows Mi-Thorium cache-policy reference
`cfc3ae9f0c94e2ce73b9e9361d8a91e680bfbbaf`; 0024 follows Android15 helper
`8a4e6793439e6e63b041be6505fd16f8b9a03879`, adapted to Android16 capture APIs.
