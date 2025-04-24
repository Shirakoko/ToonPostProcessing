Shader "Hidden/Backlit"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _CharacterTex ("Character Texture", 2D) = "black" {}
        _BackgroundTex ("Background Texture", 2D) = "black" {}
        _Threshold ("Alpha Threshold", Range(0,1)) = 0.1
        _BlurSize ("Blur Size", Range(0, 0.1)) = 0.01
        _ClearColor ("Clear Color", Color) = (0,0,0,0)
    }
    
    SubShader
    {
        // Pass 0: 双摄像机合成
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_composite
            #include "UnityCG.cginc"

            sampler2D _CharacterTex;
            sampler2D _BackgroundTex;
            float _Threshold;

            fixed4 frag_composite (v2f_img i) : SV_Target
            {
                fixed4 bgCol = tex2D(_BackgroundTex, i.uv);
                fixed4 charCol = tex2D(_CharacterTex, i.uv);
                return (charCol.a > _Threshold) ? charCol : bgCol;
            }
            ENDCG
        }
        
        // Pass 1: 从背景中抠除角色
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_mask
            #include "UnityCG.cginc"
            
            sampler2D _CharacterTex;
            sampler2D _BackgroundTex;
            float _Threshold;
            fixed4 _ClearColor;
            
            fixed4 frag_mask (v2f_img i) : SV_Target
            {
                fixed4 character = tex2D(_CharacterTex, i.uv);
                fixed4 background = tex2D(_BackgroundTex, i.uv);
                return (character.a > _Threshold) ? _ClearColor : background;
            }
            ENDCG
        }
        
        // Pass 2: 高斯模糊处理
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_blur
            #include "UnityCG.cginc"
            
            sampler2D _MainTex;
            float _BlurSize;
            float4 _MainTex_TexelSize;
            
            fixed4 frag_blur (v2f_img i) : SV_Target {
                // 标准3×3高斯核权重
                float weights[3][3] = {
                    {0.0625, 0.125, 0.0625},
                    {0.125,  0.25,  0.125 },
                    {0.0625, 0.125, 0.0625}
                };
            
                // 纹理像素大小（用于偏移计算）
                float2 texelSize = _MainTex_TexelSize.xy * _BlurSize;
                
                fixed4 col = fixed4(0, 0, 0, 0);
                // 遍历3×3邻域
                for (int x = -1; x <= 1; x++) {
                    for (int y = -1; y <= 1; y++) {
                        float2 offset = float2(x, y) * texelSize;
                        col += tex2D(_MainTex, i.uv + offset) * weights[x+1][y+1];
                    }
                }
                
                return col;
            }
            ENDCG
        }
        
        // Pass 3: 模糊遮罩与角色取交集
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_intersect
            #include "UnityCG.cginc"
            
            sampler2D _CharacterTex;
            sampler2D _MainTex;
            float _Threshold;
            fixed4 _ClearColor;
            
            fixed4 frag_intersect (v2f_img i) : SV_Target
            {
                fixed4 character = tex2D(_CharacterTex, i.uv);
                fixed4 blurredCol = tex2D(_MainTex, i.uv);
                return (character.a > _Threshold) ? blurredCol : _ClearColor;
            }
            ENDCG
        }
        
        // Pass 4: 最终合成
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_final
            #include "UnityCG.cginc"
            
            sampler2D _CharacterTex;
            sampler2D _BackgroundTex;
            sampler2D _MaskedBlurTex;
            float _Threshold;
            
            fixed4 frag_final (v2f_img i) : SV_Target
            {
                fixed4 character = tex2D(_CharacterTex, i.uv);
                fixed4 originalBG = tex2D(_BackgroundTex, i.uv);
                fixed4 maskedBlur = tex2D(_MaskedBlurTex, i.uv);
                
                fixed4 final = originalBG;
                if (character.a > _Threshold) 
                {
                    // 加法混合
                    fixed3 additiveBlend = character.rgb + maskedBlur.rgb;
                    // maskedBlur.a控制混合程度
                    final.rgb = lerp(character.rgb, additiveBlend, maskedBlur.a);
                }
                return final;
            }
            ENDCG
        }
    }
}