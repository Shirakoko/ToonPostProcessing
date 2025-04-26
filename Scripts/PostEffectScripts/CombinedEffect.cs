using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class CombinedEffect : MonoBehaviour
{
    [Header("效果控制开关")]
    public bool enableEffects = true;

    [Header("摄像机设置")]
    public Camera characterCamera;
    public Camera backgroundCamera;
    
    [Header("渲染纹理")]
    public RenderTexture characterTexture;
    public RenderTexture backgroundTexture;
    
    [Header("柔光效果")]
    public bool enableDiffuseEffect = true;
    [Range(0, 1)] public float alphaThreshold = 0.1f;
    [Range(0, 1)] public float bloomIntensity = 0.5f;
    [Range(0, 1)] public float bloomThreshold = 0.7f;
    [Range(0, 0.02f)] public float diffuseBlurSize = 0.005f;
    [Range(1, 4)] public int diffuseBlurIterations = 2;
    
    [Header("背景透光效果")]
    public bool enableBacklitEffect = true;
    [Range(0, 0.02f)] public float backlitBlurSize = 0.005f;
    [Range(1, 4)] public int backlitBlurIterations = 2;
    
    [Header("暗部晕染效果")]
    public bool enableDarkBlurEffect = true;
    [Range(0, 0.02f)] public float darkBlurSize = 0.005f;
    [Range(1, 4)] public int darkBlurIterations = 2;
    public Color blurredColor = Color.grey;
    
    [Header("混合设置")]
    [Range(0, 1)] public float diffuseBlendFactor = 0.5f;
    [Range(0, 1)] public float backlitBlendFactor = 0.5f;
    [Range(0, 1)] public float darkBlurBlendFactor = 0.5f;
    
    // 材质
    private Material _diffuseMaterial;
    private Material _backlitMaterial;
    private Material _darkBlurMaterial;
    private Material _blendMaterial;

    void OnEnable()
    {
        // 初始化所有材质
        _diffuseMaterial = new Material(Shader.Find("Hidden/Diffuse"));
        _backlitMaterial = new Material(Shader.Find("Hidden/Backlit"));
        _darkBlurMaterial = new Material(Shader.Find("Hidden/DarkBlur"));
        _blendMaterial = new Material(Shader.Find("Hidden/Blend"));
        
        _diffuseMaterial.hideFlags = HideFlags.HideAndDontSave;
        _backlitMaterial.hideFlags = HideFlags.HideAndDontSave;
        _darkBlurMaterial.hideFlags = HideFlags.HideAndDontSave;
        _blendMaterial.hideFlags = HideFlags.HideAndDontSave;
        
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
        
        // 创建临时纹理
        RenderTexture compositeRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        RenderTexture diffuseRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        RenderTexture backlitRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        RenderTexture darkBlurRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        RenderTexture finalRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        
        // 双摄像机合成
        _diffuseMaterial.SetTexture("_CharacterTex", characterTexture);
        _diffuseMaterial.SetTexture("_BackgroundTex", backgroundTexture);
        Graphics.Blit(null, compositeRT, _diffuseMaterial, 0);

        // 如果没有开启效果或全局关闭，直接输出
        if(!enableEffects)
        {
            Graphics.Blit(compositeRT, dest);
            CleanupRTs(compositeRT, diffuseRT, backlitRT, darkBlurRT, finalRT);
            return;
        }
        
        // 1. 柔光效果处理
        if(enableDiffuseEffect) {
            ProcessDiffuseEffect(compositeRT, diffuseRT);
        } else {
            Graphics.Blit(compositeRT, diffuseRT);
        }
        
        // 2. 背景透光效果处理
        if(enableBacklitEffect) {
            ProcessBacklitEffect(compositeRT, backlitRT);
        } else {
            Graphics.Blit(compositeRT, backlitRT);
        }
        
        // 3. 暗部晕染效果处理
        if(enableDarkBlurEffect) {
            ProcessDarkBlurEffect(compositeRT, darkBlurRT);
        } else {
            Graphics.Blit(compositeRT, darkBlurRT);
        }
        
        // 4. 最终混合
        _blendMaterial.SetTexture("_DiffuseTex", diffuseRT);
        _blendMaterial.SetTexture("_BacklitTex", backlitRT);
        _blendMaterial.SetTexture("_DarkBlurTex", darkBlurRT);
        _blendMaterial.SetTexture("_OriginalTex", compositeRT);
        _blendMaterial.SetFloat("_DiffuseBlend", diffuseBlendFactor);
        _blendMaterial.SetFloat("_BacklitBlend", backlitBlendFactor);
        _blendMaterial.SetFloat("_DarkBlurBlend", darkBlurBlendFactor);
        Graphics.Blit(null, finalRT, _blendMaterial, 0);
        
        // 输出最终结果
        Graphics.Blit(finalRT, dest);
        
        // 释放临时纹理
        CleanupRTs(compositeRT, diffuseRT, backlitRT, darkBlurRT, finalRT);
    }
    
    void ProcessDiffuseEffect(RenderTexture source, RenderTexture destination)
    {
        // 设置参数
        _diffuseMaterial.SetFloat("_Threshold", alphaThreshold);
        _diffuseMaterial.SetFloat("_BloomThreshold", bloomThreshold);
        _diffuseMaterial.SetFloat("_BloomIntensity", bloomIntensity);
        _diffuseMaterial.SetFloat("_BlurSize", diffuseBlurSize);
        
        // 创建临时纹理
        RenderTexture brightRT = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        RenderTexture blurredBrightRT = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        
        // Pass 1: 提取高光
        _diffuseMaterial.SetTexture("_MainTex", source);
        Graphics.Blit(null, brightRT, _diffuseMaterial, 1);
        
        // Pass 2: 模糊处理
        RenderTexture currentBlur = brightRT;
        for (int i = 0; i < diffuseBlurIterations; i++)
        {
            RenderTexture nextBlur = RenderTexture.GetTemporary(
                currentBlur.width / 2, currentBlur.height / 2, 0, currentBlur.format);
            
            _diffuseMaterial.SetTexture("_MainTex", currentBlur);
            Graphics.Blit(null, nextBlur, _diffuseMaterial, 2);
            
            if (currentBlur != brightRT) RenderTexture.ReleaseTemporary(currentBlur);
            currentBlur = nextBlur;
        }

        // 将最终模糊结果复制到blurredBrightRT
        Graphics.Blit(currentBlur, blurredBrightRT);
        
        // Pass 3: 最终合成
        _diffuseMaterial.SetTexture("_MainTex", source);
        _diffuseMaterial.SetTexture("_BloomTex", currentBlur);
        Graphics.Blit(null, destination, _diffuseMaterial, 3);
        
        if (currentBlur != brightRT) RenderTexture.ReleaseTemporary(currentBlur);
        RenderTexture.ReleaseTemporary(brightRT);
        RenderTexture.ReleaseTemporary(blurredBrightRT);
    }
    
    void ProcessBacklitEffect(RenderTexture source, RenderTexture destination)
    {
        // 创建临时渲染纹理
        RenderTexture bgWithoutCharacterRT = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        RenderTexture bgBlurredRT = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        RenderTexture characterMaskRT = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);

        // Pass1：从背景中抠除角色
        _backlitMaterial.SetTexture("_CharacterTex", characterTexture);
        _backlitMaterial.SetTexture("_BackgroundTex", backgroundTexture);
        _backlitMaterial.SetFloat("_Threshold", alphaThreshold);
        Graphics.Blit(null, bgWithoutCharacterRT, _backlitMaterial, 1);

        // Pass2：模糊处理
        _backlitMaterial.SetFloat("_BlurSize", backlitBlurSize);
        RenderTexture currentBlur = bgWithoutCharacterRT;
        for (int i = 0; i < backlitBlurIterations; i++)
        {
            RenderTexture nextBlur = RenderTexture.GetTemporary(
                currentBlur.width / 2, currentBlur.height / 2, 0, currentBlur.format);
            
            _backlitMaterial.SetTexture("_MainTex", currentBlur);
            _backlitMaterial.SetVector("_MainTex_TexelSize", new Vector4(1.0f/currentBlur.width, 1.0f/currentBlur.height, currentBlur.width, currentBlur.height));
            Graphics.Blit(null, nextBlur, _backlitMaterial, 2);
            
            if (currentBlur != bgWithoutCharacterRT) RenderTexture.ReleaseTemporary(currentBlur);
            currentBlur = nextBlur;
        }
        
        // 将最终模糊结果复制到bgBlurredRT
        Graphics.Blit(currentBlur, bgBlurredRT);
        if (currentBlur != bgWithoutCharacterRT) RenderTexture.ReleaseTemporary(currentBlur);

        // Pass3：模糊后的结果和characterTexture取交集
        _backlitMaterial.SetTexture("_MainTex", bgBlurredRT);
        _backlitMaterial.SetFloat("_Threshold", alphaThreshold);
        Graphics.Blit(null, characterMaskRT, _backlitMaterial, 3);

        // Pass 4: 最终合成
        _backlitMaterial.SetTexture("_MaskedBlurTex", characterMaskRT);
        Graphics.Blit(null, destination, _backlitMaterial, 4);

        // 释放临时渲染纹理
        RenderTexture.ReleaseTemporary(bgWithoutCharacterRT);
        RenderTexture.ReleaseTemporary(bgBlurredRT);
        RenderTexture.ReleaseTemporary(characterMaskRT);
    }
    
    void ProcessDarkBlurEffect(RenderTexture source, RenderTexture destination)
    {
        // 设置参数
        _darkBlurMaterial.SetFloat("_Threshold", alphaThreshold);
        _darkBlurMaterial.SetFloat("_BlurSize", darkBlurSize / 10);
        
        // 创建临时纹理
        RenderTexture darkAreaRT = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        RenderTexture darkSoftAreaRT = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        RenderTexture finalDarkAreaRT = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        
        // Pass 1: 分离亮部和暗部
        var diffuseRT = characterCamera.GetComponent<Test>().DiffuseRT;
        _darkBlurMaterial.SetTexture("_DiffuseRT", diffuseRT);
        Graphics.Blit(null, darkAreaRT, _darkBlurMaterial, 1);

        // Pass2: 生成纯白模糊阴影遮罩
        RenderTexture currentBlur = darkAreaRT;
        for (int i = 0; i < darkBlurIterations; i++)
        {
            RenderTexture nextBlur = RenderTexture.GetTemporary(
                currentBlur.width / 2, currentBlur.height / 2, 0, currentBlur.format);
            
            _darkBlurMaterial.SetTexture("_MainTex", currentBlur);
            _darkBlurMaterial.SetVector("_MainTex_TexelSize", new Vector4(1.0f/currentBlur.width, 1.0f/currentBlur.height, currentBlur.width, currentBlur.height));
            Graphics.Blit(null, nextBlur, _darkBlurMaterial, 2);
            
            if (currentBlur != darkAreaRT) RenderTexture.ReleaseTemporary(currentBlur);
            currentBlur = nextBlur;
        }
        
        // 将最终模糊结果复制到darkSoftAreaRT
        Graphics.Blit(currentBlur, darkSoftAreaRT);
        if (currentBlur != darkAreaRT) RenderTexture.ReleaseTemporary(currentBlur);
        
        // Pass 3: 合成暗部
        _darkBlurMaterial.SetColor("_BlurredColor", blurredColor);
        _darkBlurMaterial.SetTexture("_DarkMaskTex", darkSoftAreaRT);
        Graphics.Blit(null, finalDarkAreaRT, _darkBlurMaterial, 3);
        
        // Pass 4: 最终合成 (Multiply+Add模式)
        _darkBlurMaterial.SetTexture("_CharacterTex", characterTexture);
        _darkBlurMaterial.SetTexture("_DarkAreaTex", finalDarkAreaRT);
        _darkBlurMaterial.SetTexture("_BackgroundTex", backgroundTexture);
        Graphics.Blit(null, destination, _darkBlurMaterial, 4);
        
        // 释放RT
        RenderTexture.ReleaseTemporary(darkAreaRT);
        RenderTexture.ReleaseTemporary(darkSoftAreaRT);
        RenderTexture.ReleaseTemporary(finalDarkAreaRT);
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
        if (_diffuseMaterial != null) DestroyImmediate(_diffuseMaterial);
        if (_backlitMaterial != null) DestroyImmediate(_backlitMaterial);
        if (_darkBlurMaterial != null) DestroyImmediate(_darkBlurMaterial);
        if (_blendMaterial != null) DestroyImmediate(_blendMaterial);
    }
}