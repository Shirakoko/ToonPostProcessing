using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class BacklitEffect : MonoBehaviour
{
    [Header("效果控制开关")]
    public bool enableEffect = true;

    [Header("摄像机设置")]
    public Camera characterCamera;
    public Camera backgroundCamera;
    
    [Header("渲染纹理")]
    public RenderTexture characterTexture;
    public RenderTexture backgroundTexture;
    
    [Header("着色器设置")]
    [Range(0, 1)] public float alphaThreshold = 0.1f;  // 透明度阈值
    [Range(0, 0.1f)] public float blurSize = 0.01f;     // 模糊大小
    [Range(1, 4)] public int blurIterations = 2;        // 模糊迭代次数

    private Material _material;

    void OnEnable()
    {
        // 初始化材质
        Shader shader = Shader.Find("Hidden/Backlit");
        _material = new Material(shader);
        _material.hideFlags = HideFlags.HideAndDontSave;
        
        // 设置摄像机深度
        GetComponent<Camera>().depth = 2;

        // 确保角色摄像机正确设置
        if (characterCamera != null)
        {
            characterCamera.depth = 1;
            characterCamera.clearFlags = CameraClearFlags.SolidColor;
            characterCamera.backgroundColor = new Color(0, 0, 0, 0); // 完全透明背景
            characterCamera.targetTexture = characterTexture;
        }
        
        // 背景摄像机设置
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

        // 创建临时渲染纹理
        RenderTexture bgWithoutCharacterRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        RenderTexture bgBlurredRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);
        RenderTexture characterMaskRT = RenderTexture.GetTemporary(src.width, src.height, 0, src.format);

        if(!enableEffect) {
            // Pass 0: 双摄像机合成
            _material.SetTexture("_CharacterTex", characterTexture);
            _material.SetTexture("_BackgroundTex", backgroundTexture);
            Graphics.Blit(null, dest, _material, 0);
            return;
        }

        // Pass1：从背景中抠除角色，保存结果到bgWithoutCharacterRT
        _material.SetTexture("_CharacterTex", characterTexture);
        _material.SetTexture("_BackgroundTex", backgroundTexture);
        _material.SetFloat("_Threshold", alphaThreshold);
        Graphics.Blit(null, bgWithoutCharacterRT, _material, 1);

        // Pass2：模糊bgWithoutCharacterRT，保存结果到bgBlurredRT
        _material.SetFloat("_BlurSize", blurSize);
        RenderTexture currentBlur = bgWithoutCharacterRT;
        for (int i = 0; i < blurIterations; i++)
        {
            RenderTexture nextBlur = RenderTexture.GetTemporary(
                currentBlur.width / 2, currentBlur.height / 2, 0, currentBlur.format);
            
            _material.SetTexture("_MainTex", currentBlur);
            _material.SetVector("_MainTex_TexelSize", new Vector4(1.0f/currentBlur.width, 1.0f/currentBlur.height, currentBlur.width, currentBlur.height));
            Graphics.Blit(null, nextBlur, _material, 2);
            
            if (currentBlur != bgWithoutCharacterRT) RenderTexture.ReleaseTemporary(currentBlur);
            currentBlur = nextBlur;
        }
        
        // 将最终模糊结果复制到bgBlurredRT
        Graphics.Blit(currentBlur, bgBlurredRT);
        if (currentBlur != bgWithoutCharacterRT) RenderTexture.ReleaseTemporary(currentBlur);

        // Pass3：模糊后的结果和characterTexture取交集，保存结果到characterMaskRT
        _material.SetTexture("_MainTex", bgBlurredRT);
        _material.SetFloat("_Threshold", alphaThreshold);
        Graphics.Blit(null, characterMaskRT, _material, 3);

        // Pass 4: 最终合成
        _material.SetTexture("_MaskedBlurTex", characterMaskRT);
        Graphics.Blit(null, dest, _material, 4);

        // 释放临时渲染纹理
        CleanupRTs(bgWithoutCharacterRT, bgBlurredRT, characterMaskRT);
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
        // 清理资源
        if (_material != null) DestroyImmediate(_material);
    }
}