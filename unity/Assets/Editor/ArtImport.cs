using UnityEditor;
using UnityEngine;

/// <summary>
/// Every picture under Assets/Resources/Art imports as a sprite at 64 pixels per unit (one tile = one unit, as in
/// the Godot rooms), smooth (painted art, not pixel art), at full size (Janani's strips are up to 6600 px wide).
/// </summary>
public class ArtImport : AssetPostprocessor
{
    void OnPreprocessTexture()
    {
        if (!assetPath.StartsWith("Assets/Resources/Art/"))
            return;
        // the Asset Store packs' sheets keep their own settings (cut into named pieces, crisp pixel art)
        if (assetPath.StartsWith("Assets/Resources/Art/Village/") || assetPath.StartsWith("Assets/Resources/Art/Forest/") ||
            assetPath.StartsWith("Assets/Resources/Art/UI/") || assetPath.StartsWith("Assets/Resources/Art/Hills/"))
            return;
        var t = (TextureImporter)assetImporter;
        t.textureType = TextureImporterType.Sprite;
        t.spriteImportMode = SpriteImportMode.Single;
        t.spritePixelsPerUnit = 64;
        t.mipmapEnabled = false;
        t.filterMode = FilterMode.Bilinear;
        t.wrapMode = TextureWrapMode.Clamp;
        t.alphaIsTransparency = true;
        t.maxTextureSize = 8192;
        t.npotScale = TextureImporterNPOTScale.None;
        t.textureCompression = TextureImporterCompression.CompressedHQ;
    }
}
