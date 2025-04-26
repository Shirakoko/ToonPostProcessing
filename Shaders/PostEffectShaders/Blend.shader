Shader "Hidden/Blend"
{
    Properties
    {
        _DiffuseTex ("Diffuse Texture", 2D) = "white" {}
        _BacklitTex ("Backlit Texture", 2D) = "white" {}
        _DarkBlurTex ("Dark Blur Texture", 2D) = "white" {}
        _OriginalTex ("Original Texture", 2D) = "white" {}
        _DiffuseBlend ("Diffuse Blend Factor", Range(0, 1)) = 0.5
        _BacklitBlend ("Backlit Blend Factor", Range(0, 1)) = 0.5
        _DarkBlurBlend ("Dark Blur Blend Factor", Range(0, 1)) = 0.5
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #include "UnityCG.cginc"
            
            sampler2D _DiffuseTex;
            sampler2D _BacklitTex;
            sampler2D _DarkBlurTex;
            sampler2D _OriginalTex;
            float _DiffuseBlend;
            float _BacklitBlend;
            float _DarkBlurBlend;

            // 变亮混合函数
            float3 blendLighten(float3 base, float3 blend, float opacity)
            {
                return lerp(base, max(base, blend), opacity);
            }
            
            fixed4 frag (v2f_img i) : SV_Target
            {
                fixed4 original = tex2D(_OriginalTex, i.uv);
                fixed4 diffuse = tex2D(_DiffuseTex, i.uv);
                fixed4 backlit = tex2D(_BacklitTex, i.uv);
                fixed4 darkBlur = tex2D(_DarkBlurTex, i.uv);

                // 初始结果为原始图像
                fixed4 result = original;
                
                // 应用柔光效果（变亮混合）
                result.rgb = blendLighten(result.rgb, diffuse.rgb, _DiffuseBlend);
                
                // 应用背景透光效果（变亮混合）
                result.rgb = blendLighten(result.rgb, backlit.rgb, _BacklitBlend);
                
                // 应用暗部晕染效果（变亮混合）
                result.rgb = blendLighten(result.rgb, darkBlur.rgb, _DarkBlurBlend);
                
                return result;
            }
            ENDCG
        }
    }
}