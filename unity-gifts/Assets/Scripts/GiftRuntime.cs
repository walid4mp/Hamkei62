using System.Collections;
using System.IO;
using System.Linq;
using GLTFast;
using UnityEngine;

public sealed class GiftRuntime : MonoBehaviour
{
    public Transform spawnRoot;
    public Camera giftCamera;

    GiftManifest manifest;
    GameObject activeGift;
    Coroutine activeRoutine;

    void Awake()
    {
        if (spawnRoot == null) spawnRoot = transform;
        if (giftCamera == null) giftCamera = Camera.main;
        var json = Resources.Load<TextAsset>("gift_manifest");
        if (json != null) manifest = JsonUtility.FromJson<GiftManifest>(json.text);
    }

    public void PlayGift(string giftId, string senderName, int quantity = 1)
    {
        if (manifest == null || manifest.gifts == null) return;
        var gift = manifest.gifts.FirstOrDefault(x => x.id == giftId);
        if (gift == null) return;
        if (activeRoutine != null) StopCoroutine(activeRoutine);
        activeRoutine = StartCoroutine(Play(gift, senderName, Mathf.Clamp(quantity, 1, 99)));
    }

    IEnumerator Play(GiftDefinition gift, string senderName, int quantity)
    {
        if (activeGift != null) Destroy(activeGift);
        var path = Path.Combine(Application.streamingAssetsPath, "GiftModels", gift.id + ".glb");
        var import = new GltfImport();
        var task = import.Load(path);
        while (!task.IsCompleted) yield return null;
        if (!task.Result) yield break;

        activeGift = new GameObject("Gift_" + gift.id);
        activeGift.transform.SetParent(spawnRoot, false);
        var inst = import.InstantiateMainSceneAsync(activeGift.transform);
        while (!inst.IsCompleted) yield return null;
        if (!inst.Result) { Destroy(activeGift); yield break; }

        // V105 premium motion families. The same GLB can therefore have a
        // distinct entrance/exit profile driven by the catalog effectKey.
        var duration = Mathf.Clamp(gift.effectMs / 1000f, 1.2f, 12f);
        var rarityScale = gift.rarity == "MYTHIC" ? 1.5f : gift.rarity == "LEGENDARY" ? 1.28f : gift.rarity == "EPIC" ? 1.15f : 1f;
        var start = activeGift.transform.localScale * 0.03f;
        var end = activeGift.transform.localScale * rarityScale;
        activeGift.transform.localScale = start;
        var seed = Mathf.Abs(gift.id.GetHashCode());
        var spin = 120f + (seed % 420);
        var profile = seed % 6;
        float t = 0;
        while (t < duration)
        {
            t += Time.deltaTime;
            var p = Mathf.Clamp01(t / duration);
            var ease = 1f - Mathf.Pow(1f - p, 3f);
            activeGift.transform.localScale = Vector3.LerpUnclamped(start, end, ease);
            var pulse = 1f + Mathf.Sin(p * Mathf.PI * (2f + profile)) * 0.045f;
            activeGift.transform.localScale *= pulse;
            activeGift.transform.Rotate(Vector3.up, spin * Time.deltaTime, Space.Self);
            var arc = Mathf.Sin(p * Mathf.PI);
            var side = Mathf.Sin(p * Mathf.PI * (profile + 1)) * (0.08f + rarityScale * 0.04f);
            activeGift.transform.position = spawnRoot.position + new Vector3(side, arc * (0.12f + rarityScale * 0.18f), 0);
            yield return null;
        }
        Destroy(activeGift);
        activeRoutine = null;
    }
}
