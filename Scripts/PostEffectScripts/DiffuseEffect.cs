using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class DiffuseEffect : MonoBehaviour
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
    [Range(0, 1)] public float bloomIntensity = 0.5f;
    [Range(0, 1)] public float bloomThreshold = 0.7f;
    [Range(0, 0.02f)] public float blurSize = 0.005f;
    [Range(1, 4)] public int blurIterations = 2;

    private Material _material;

    void OnEnable()
    {
        _material = new Material(Shader.Find("Hidden/Diffuse"));
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
        if (characterTexture == null || backgroundTexture == null)
        {
            Graphics.Blit(src, dest);
            return;
        }
        
        // 设置参数
        _material.SetFloat("_Threshold", alphaThreshold);
        _material.SetFloat("_BloomThreshold", bloomThreshold);
        _material.SetFloat("_BloomIntensity", bloomIntensity);
        _material.SetFloat("_BlurSize", blurSize);
        
        // 创建临时纹理
        RenderTexture compositeRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        RenderTexture brightRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        
        // Pass 0: 双摄像机合成
        _material.SetTexture("_CharacterTex", characterTexture);
        _material.SetTexture("_BackgroundTex", backgroundTexture);
        Graphics.Blit(null, compositeRT, _material, 0);

        if(!enableEffect) {
            Graphics.Blit(compositeRT, dest);
            CleanupRTs(compositeRT, brightRT);
            return;
        }
        
        // Pass 1: 提取高光
        _material.SetTexture("_MainTex", compositeRT);
        Graphics.Blit(null, brightRT, _material, 1);
        
        // Pass 2: 模糊处理
        RenderTexture currentBlur = brightRT;
        for (int i = 0; i < blurIterations; i++)
        {
            RenderTexture nextBlur = RenderTexture.GetTemporary(
                currentBlur.width / 2, currentBlur.height / 2, 0, currentBlur.format);
            
            _material.SetTexture("_MainTex", currentBlur);
            Graphics.Blit(null, nextBlur, _material, 2);
            
            if (currentBlur != brightRT) RenderTexture.ReleaseTemporary(currentBlur);
            currentBlur = nextBlur;
        }
        
        // Pass 3: 最终合成
        _material.SetTexture("_MainTex", compositeRT);
        _material.SetTexture("_BloomTex", currentBlur);
        Graphics.Blit(null, dest, _material, 3);
        
        // 释放RT
        if (currentBlur != brightRT) RenderTexture.ReleaseTemporary(currentBlur);
        CleanupRTs(compositeRT, brightRT);
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