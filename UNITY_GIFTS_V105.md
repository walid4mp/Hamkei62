# SocialNova V105 — Unity/GLB Live Gift Integration

- Flutter receives authoritative `live:gift` events and forwards them to `UnityGiftBridge`.
- Existing Flutter gift renderer remains the runtime fallback until a Unity Android Library export is linked.
- Native MethodChannel contract: `socialnova/unity_gifts` (`isAvailable`, `show`, `hide`, `playGift`).
- Unity GiftRuntime supports deterministic motion profiles and reads the existing 210-gift manifest.
- Server remains authoritative for gift validation, wallet deduction and realtime fan-out.
- App version: 3.9.0+21.

## Verification
- Confirmed all 210 GLB files have valid GLB magic bytes (`glTF`).
- Confirmed Android bridge is compile-safe without Unity classes.
- Unity Android Library export and final APK build require a Unity installation/Android export environment; this package does not claim that step has been executed here.
