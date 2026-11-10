# LineageOS 23.2 platform integration

Place the three trees at `device/nokia/PLE`, `vendor/nokia/PLE` and
`kernel/nokia/msm8937` in the Android source root. No Nokia common tree is used.

Apply the patches below to their indicated platform repositories in numerical
order before a normal build. The source payloads are unchanged from the working
integration. Preserve upstream licenses and use the pinned revisions below.

| Patches | Repository | Base revision |
| --- | --- | --- |
| 0001, 0007 | hardware/qcom-caf/msm8998/display | dcede86f9cd0215da892a7cc37eb28f738c0868d |
| 0002 | packages/apps/Launcher3 | f83fbe24ed3c0bd3c4d7cd3186ffadefeda5b7db |
| 0003, 0010, 0011, 0019, 0023 | hardware/lineage/interfaces | 805d25348106e8cc6f378c0b153789f3cf8da667 |
| 0004, 0006 | hardware/qcom-caf/sdm660/media | 2098857ca9e357840703605c1520c9a9b4c21ff2 |
| 0005 | hardware/qcom-caf/msm8998/media | 125f0e38ef5c289421d39f9710e24a3c9c04fbf2 |
| 0008 | packages/apps/Glimpse | 8de08089dcd87a753c2c23e5861563238f681e99 |
| 0009, 0024 | frameworks/base | 958afcc3d647d57571650cee4172afe0da619171 |
| 0012 | system/sepolicy | 885cc500f6078a766d1f6def5ce4c06c55841773 |
| 0013, 0015 | hardware/interfaces | 13d687a84c834af855bfb314b853b8372a7aa6d9 |
| 0014 | packages/apps/AudioFX | cd989d5081978b062230da28ca20c353b0afd8c3 |
| 0016, 0017 | hardware/lineage/compat | 4d124113ee007e7508cbd10515bea5eb0cd433ab |
| 0018, 0020 | hardware/ril | cec58d16c72a4fb5a075c1671e2a494920797e24 |
| 0021, 0022 | frameworks/opt/telephony | a6e94555e0d750e4557f5371811b776637ab7c50 |

From the Android root, check and apply each patch with:

```sh
git -C <repository> apply --check "$PWD/device/nokia/PLE/patches/<patch>"
git -C <repository> apply "$PWD/device/nokia/PLE/patches/<patch>"
```

On an already-patched checkout, `git apply --reverse --check` recognizes the
installed state; do not apply a patch twice. Patches 0020 and 0022 depend on
0018 and 0021 respectively. Build the normal complete affected modules, not
isolated framework JARs or cached APK fragments.

Exception: patch 0024 retains Android-root path prefixes. Inside frameworks/base,
strip those two additional components with `-p3` for both the check and apply:

```sh
git -C frameworks/base apply -p3 --check "$PWD/device/nokia/PLE/patches/0024-ple-legacy-activity-edge-extension.patch"
git -C frameworks/base apply -p3 "$PWD/device/nokia/PLE/patches/0024-ple-legacy-activity-edge-extension.patch"
```

Use `-p3` for its reverse check as well. All other patches use the default `-p1`.

Display patch 0007 follows Mi-Thorium's split-usage cache-policy contract at
cfc3ae9f0c94e2ce73b9e9361d8a91e680bfbbaf. Activity-edge patch 0024 follows
the Android 15 helper at 8a4e6793439e6e63b041be6505fd16f8b9a03879,
adapted to Android 16 capture APIs. Neither changes the Nokia stock buffer ABI.

Populate the private vendor inputs before building; their extraction helpers
and pinned manifests are in `vendor/nokia/PLE/tools` and `config/manifests`.
The current source selection has two unresolved Wi-Fi inputs:
`vendor/etc/wifi/WCNSS_qcom_cfg.ini` and
`vendor/firmware/wlan/prima/WCNSS_cfg.dat`. Supply the exact stock inputs;
do not substitute another device's firmware or configuration.

Use the LineageOS product `lineage_PLE` with the branch's normal lunch/build
workflow. The kernel is source-built using the fragments in BoardConfig.mk.
