using UnityEngine;

public sealed class UnityGiftBridge : MonoBehaviour
{
    public GiftRuntime runtime;

    public void PlayGiftMessage(string message)
    {
        if (runtime == null || string.IsNullOrWhiteSpace(message)) return;
        var msg = JsonUtility.FromJson<GiftMessage>(message);
        runtime.PlayGift(msg.giftId, msg.senderName, msg.quantity);
    }

    [System.Serializable]
    public sealed class GiftMessage
    {
        public string giftId;
        public string senderName;
        public int quantity = 1;
        public string rarity;
        public string effectKey;
        public string soundKey;
    }

    // Called by the Android/Flutter bridge after Unity is embedded.
    public void OnGiftEvent(string json) => PlayGiftMessage(json);
}
