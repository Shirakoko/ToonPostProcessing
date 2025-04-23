using UnityEngine;
using UnityEngine.Rendering;
using System.Collections.Generic;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class Test : MonoBehaviour
{
    [Header("角色的SkinnedMeshRenderer")]
    public List<SkinnedMeshRenderer> characterRenderers;
    [Header("启用测试模式")]
    public bool testMode;

    [Header("阴影阈值")]
    [Range(-1.0f, 1.0f)]public float shadowThreshold = 0.2f;

    private Camera _camera;
    private CommandBuffer _cmdBuffer;

    /** _diffuseRT 对象存储 RenderTexture */
    private RenderTexture _diffuseRT;

    public RenderTexture DiffuseRT 
    {
        get { return _diffuseRT; }
    }
    
    private Material _diffuseMaterial;

    // 需要输出 DiffuseValue 的材质名称列表（先硬编码）
    private HashSet<string> _targetMaterialNames = new HashSet<string>
    {
        "0.Face_",
        "14.UP_Skin",
        "24.Down_Skin",
        "9.Hair_Back",
        "10.Hair_Bow",
        "11.Hair_Tail",
        "12.Hair_Bangs",
        "13.Up",
        "15.UP_Glove",
        "16.UP_Flower",
        "17.UP_Hood",
        "19.UP_Hairpin",
        "20.Down",
        "21.Down_Shoe",
        "22.Down_Sock",
        "23.Down_Flower"
    };

    void OnEnable()
    {
        _camera = GetComponent<Camera>();
        _diffuseRT = new RenderTexture(Screen.width, Screen.height, 24, RenderTextureFormat.RFloat); // 24位深度
        _diffuseRT.Create();

        _diffuseMaterial = new Material(Shader.Find("Custom/Single-Faced Toon"));
        _diffuseMaterial.SetFloat("_ShadowThreshold", shadowThreshold); // 设置阴影阈值
        _diffuseMaterial.hideFlags = HideFlags.HideAndDontSave;

        _cmdBuffer = new CommandBuffer();
        _cmdBuffer.name = "Toon Diffuse Prepass";

        // 清空 RenderTexture
        _cmdBuffer.SetRenderTarget(_diffuseRT);
        _cmdBuffer.ClearRenderTarget(true, true, Color.clear);

        // 遍历所有 SkinnedMeshRenderer 和它们的 Materials
        foreach (var renderer in characterRenderers)
        {
            if (renderer != null && renderer.isVisible)
            {
                var materials = renderer.sharedMaterials;
                for (int i = 0; i < materials.Length; i++)
                {
                    var material = materials[i];
                    // 检查 Material 名称是否在目标列表中
                    if (material != null && _targetMaterialNames.Contains(material.name))
                    {
                        _cmdBuffer.DrawRenderer(renderer, _diffuseMaterial, i, 0);
                    }
                }
            }
        }

        _cmdBuffer.SetGlobalTexture("_DiffuseRT", _diffuseRT);
        _camera.AddCommandBuffer(CameraEvent.BeforeForwardOpaque, _cmdBuffer);
    }

    // 调试：显示_DiffuseRT内容
    void OnRenderImage(RenderTexture src, RenderTexture dest) {
        if(testMode && _diffuseRT != null) {
            Graphics.Blit(_diffuseRT, dest);
            return;
        }
        Graphics.Blit(src, dest);
    }

    void OnDisable()
    {
        if (_cmdBuffer != null)
        {
            _camera.RemoveCommandBuffer(CameraEvent.BeforeForwardOpaque, _cmdBuffer);
            _cmdBuffer.Dispose();
        }
        if (_diffuseRT != null) _diffuseRT.Release();
        if (_diffuseMaterial != null) DestroyImmediate(_diffuseMaterial);
    }

    /** 通过禁用和启用脚本，刷新CommandBuffer */
    public void RefreshCommandBuffer()
    {
        OnDisable();
        OnEnable();
    }
}