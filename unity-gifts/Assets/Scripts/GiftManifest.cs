using System;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
public sealed class GiftDefinition
{
    public string id;
    public string name;
    public string nameEn;
    public int priceCoins;
    public string rarity;
    public string category;
    public string effectKey;
    public int effectMs;
    public string soundKey;
    public string assetKey;
    public string modelPath;
    public string animationKey;
}

[Serializable]
public sealed class GiftManifest
{
    public int version;
    public List<GiftDefinition> gifts;
}
