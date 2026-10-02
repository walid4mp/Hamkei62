# SocialNova Unity 3D Gift Runtime

This is the first real Unity/GLB runtime layer for SocialNova LIVE gifts.

## What is included
- 210 unique gift IDs from the existing SocialNova catalog.
- One GLB prototype asset per gift ID, generated deterministically and ready to be replaced by artist-grade GLBs without changing IDs.
- Gift manifest shared with the Flutter/API layer.
- Runtime GLB loading using Unity glTFast.
- Distinct scale/rotation/timing profiles driven by gift metadata.
- Android/Flutter bridge entry point: `UnityGiftBridge.OnGiftEvent(json)`.

## Event format
```json
{"giftId":"luxury_001","senderName":"Lina","quantity":1}
```

## Important
The included GLBs are **technical prototype meshes**, not final TikTok-grade artist assets. The architecture is production-oriented: each gift has a stable ID and independent GLB slot, so replacing `Assets/StreamingAssets/GiftModels/<giftId>.glb` with a professionally authored model/animation does not require Flutter/API changes.

The Unity Android export must be generated with Unity 2022.3 LTS (or a compatible newer LTS), then added as the Android Unity Library/module to the Flutter app. The current repository does not contain a pre-exported `unityLibrary`, so this package intentionally does not fake one.


## V105 integration contract
The Flutter app calls `socialnova/unity_gifts` with `playGift`. The Android handler currently reports unavailable until a Unity Android Library export is installed. This is intentional: a raw Unity project cannot be linked into a Flutter APK without Unity's Android export step. The app therefore falls back to the existing Flutter gift renderer rather than failing at runtime.

When exporting Unity as an Android Library, wire the exported activity/library to the same channel and forward `playGift(json)` to `UnityGiftBridge.OnGiftEvent`. Keep the server as the authority for wallet deduction and gift events.
