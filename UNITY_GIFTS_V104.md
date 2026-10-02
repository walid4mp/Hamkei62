# SocialNova V104 — Unity/GLB Gift Runtime

## Implemented
- 210 stable gift IDs mapped to 210 individual GLB files.
- Unity project skeleton with glTFast runtime loader.
- Flutter `UnityGiftBridge` MethodChannel contract.
- Backend `/api/gifts/unity-manifest` allow-listed manifest.
- Existing `/api/wallet/gifts` remains unchanged for wallet/catalog behavior.
- Each gift has independent model path and animation key; no duplicated IDs/names are introduced.

## Build integration
1. Open `unity-gifts` in Unity 2022.3 LTS.
2. Verify the project imports `com.unity.cloud.gltfast`.
3. Create/export the Android Unity Library (`unityLibrary`).
4. Add the exported Unity Library to `flutter-app/android` using Unity's documented Android embedding flow.
5. Register the Android MethodChannel `socialnova/unity_gifts` and route `playGift` to `UnityGiftBridge.OnGiftEvent(json)`.
6. In the Live screen, after the backend confirms a gift transaction/event, call `UnityGiftBridge.play(...)`.

## Asset quality
The 210 included GLBs are **technical prototype meshes generated from the catalog** so the full pipeline can be tested now. They are not claimed to be final artist-grade TikTok assets. Replace them one-by-one with professionally modeled/rigged GLBs and animations using the same filenames. No API, database, gift IDs, or Flutter UI changes are required.
