using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class DarkBlurEffect : MonoBehaviour
{
    [Header("效果控制开关")]
    public bool enableEffect = true;

    [Header("摄像机设置")]
    public Camera characterCamera;
    public Camera backgroundCamera;
    
    [Header("渲染纹理")]
    public RenderTexture characterTexture;
    public RenderTexture backgroundTexture;
    
    [Header("效果参数")]
    [Range(0, 1)] public float alphaThreshold = 0.1f;
    [Range(0, 1)] public float brightnessThreshold = 0.5f;
    [Range(0, 0.02f)] public float blurSize = 0.005f;
    [Range(1, 4)] public int blurIterations = 2;
    public Color blurredColor = Color.grey;

    private Material _material;

    void OnEnable()
    {
        _material = new Material(Shader.Find("Hidden/DarkBlur"));
        _material.hideFlags = HideFlags.HideAndDontSave;
        
        // 设置摄像机
        GetComponent<Camera>().depth = 2;
        
        if (characterCamera != null)
        {
            characterCamera.depth = 1;
            characterCamera.clearFlags = CameraClearFlags.SolidColor;
            characterCamera.backgroundColor = new Color(0, 0, 0, 0);
            characterCamera.targetTexture = characterTexture;
        }
        
        if (backgroundCamera != null)
        {
            backgroundCamera.depth = 0;
            backgroundCamera.clearFlags = CameraClearFlags.SolidColor;
            backgroundCamera.targetTexture = backgroundTexture;
        }
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (characterTexture == null || backgroundTexture == null || _material == null)
        {
            Graphics.Blit(src, dest);
            return;
        }
        
        // 设置参数
        _material.SetFloat("_Threshold", alphaThreshold);
        _material.SetFloat("_BrightnessThreshold", brightnessThreshold);
        _material.SetFloat("_BlurSize", blurSize / 10);

        
        // 创建临时纹理
        RenderTexture compositeRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        RenderTexture whiteShadowRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        RenderTexture shadowMaskRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        RenderTexture finalShadowRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        
        // Pass 0: 双摄像机合成
        _material.SetTexture("_CharacterTex", characterTexture);
        _material.SetTexture("_BackgroundTex", backgroundTexture);
        Graphics.Blit(null, compositeRT, _material, 0);

        // 未开启特效则直接输出渲染结果
        if(!enableEffect) {
            Graphics.Blit(compositeRT, dest);
            CleanupRTs(compositeRT, whiteShadowRT, shadowMaskRT, finalShadowRT);
            return;
        }

        // 得到角色摄像机上的渲染脚本保存的DiffuseRT对象，设置给shadowRT
        var diffuseRT = characterCamera.GetComponent<Test>().DiffuseRT;
        _material.SetTexture("_DiffuseRT", diffuseRT);
        // Pass 1: 分离亮部和暗部，暗部保存到shadowRT
        Graphics.Blit(null, whiteShadowRT, _material, 1);

        // Pass3: 生成纯白模糊阴影遮罩
        RenderTexture currentBlur = whiteShadowRT;
        for (int i = 0; i < blurIterations; i++)
        {
            RenderTexture nextBlur = RenderTexture.GetTemporary(
                currentBlur.width / 2, currentBlur.height / 2, 0, currentBlur.format);
            
            _material.SetTexture("_MainTex", currentBlur);
            _material.SetVector("_MainTex_TexelSize", new Vector4(1.0f/currentBlur.width, 1.0f/currentBlur.height, currentBlur.width, currentBlur.height));
            Graphics.Blit(null, nextBlur, _material, 2);
            
            if (currentBlur != whiteShadowRT) RenderTexture.ReleaseTemporary(currentBlur);
            currentBlur = nextBlur;
        }
        
        // 将最终模糊结果复制到shadowMaskRT
        Graphics.Blit(currentBlur, shadowMaskRT);
        if (currentBlur != whiteShadowRT) RenderTexture.ReleaseTemporary(currentBlur);
        
        // Pass 3: 合成阴影并取反alpha
        _material.SetColor("_BlurredColor", blurredColor);
        _material.SetTexture("_ShadowMaskTex", shadowMaskRT);
        Graphics.Blit(null, finalShadowRT, _material, 3);

        
        // Pass 4: 最终合成 (Screen模式)
        _material.SetTexture("_CharacterTex", characterTexture);
        _material.SetTexture("_ShadowTex", finalShadowRT);
        Graphics.Blit(compositeRT, dest, _material, 4);
        
        // 释放RT
        CleanupRTs(compositeRT, whiteShadowRT, shadowMaskRT, finalShadowRT);
    }

    void CleanupRTs(params RenderTexture[] rts)
    {
        foreach (var rt in rts)
        {
            if (rt != null) RenderTexture.ReleaseTemporary(rt);
        }
    }

    void OnDisable()
    {
        if (_material != null) DestroyImmediate(_material);
    }
}