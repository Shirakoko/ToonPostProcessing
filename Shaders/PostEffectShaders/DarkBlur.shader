Shader "Hidden/DarkBlur"
{
    Properties
    {
        _CharacterTex ("Character Texture", 2D) = "black" {}
        _BackgroundTex ("Background Texture", 2D) = "black" {}
        _Threshold ("Alpha Threshold", Range(0,1)) = 0.1
        
        // 阴影效果参数
        _BrightnessThreshold ("Brightness Threshold", Range(0,1)) = 0.5
        _ClearColor ("Clear Color", Color) = (0,0,0,0)
        _BlurSize ("Blur Size", Range(0, 0.01)) = 0.005
        _BlurredColor ("Blurred Color", Color) = (0.5,0.5,0.5,1)
    }
    
    SubShader
    {
        Cull Off 
        ZWrite Off 
        ZTest Always

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
                
                // 根据alpha阈值混合
                return (charCol.a > _Threshold) ? charCol : bgCol;
            }
            ENDCG
        }

        // Pass 1: 根据暗部遮罩得到纯白色硬边缘暗部
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_separate
            #include "UnityCG.cginc"

            sampler2D _CharacterTex;
            sampler2D _DiffuseRT;
            fixed4 _ClearColor;

            fixed4 frag_separate (v2f_img i) : SV_Target
            {
                fixed4 charCol = tex2D(_CharacterTex, i.uv);
                float diffuseCol = tex2D(_DiffuseRT, i.uv).r;
                
                // 如果在阴影遮罩内，返回颜色，否则返回透明
                return (diffuseCol == 0.0) ? fixed4(1,1,1,1) : _ClearColor;;
            }
            ENDCG
        }

        // Pass 2: 生成纯白模糊阴影遮罩
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_dark_area_mask
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _BlurSize;

            fixed4 frag_dark_area_mask (v2f_img i) : SV_Target
            {
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

        // Pass 3: 合成阴影并取反alpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_dark_area_alpha
            #include "UnityCG.cginc"

            fixed4 _BlurredColor;
            sampler2D _DarkMaskTex;

            fixed4 frag_dark_area_alpha (v2f_img i) : SV_Target
            {
                fixed4 maskCol = tex2D(_DarkMaskTex, i.uv);
                
                fixed4 result = lerp(fixed4(0,0,0,0), _BlurredColor, maskCol.a); // 颜色映射
                result.a = 1.0 - result.a; // 使用遮罩的alpha控制白色强度
                return result;
            }
            ENDCG
        }

        // Pass 4: 最终合成 (Multiply + Add模式)
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_final
            #include "UnityCG.cginc"

            sampler2D _CharacterTex;
            sampler2D _BackgroundTex;
            sampler2D _DarkAreaTex;
            float _Threshold;

            fixed4 frag_final (v2f_img i) : SV_Target
            {
                fixed4 charCol = tex2D(_CharacterTex, i.uv);
                fixed4 darkAreaCol = tex2D(_DarkAreaTex, i.uv);
                fixed4 bgCol = tex2D(_BackgroundTex, i.uv);
                
                // Multiply + Add 混合
                fixed3 blendedColor = charCol.rgb * (1.0 + darkAreaCol.rgb * darkAreaCol.a);
                blendedColor = min(blendedColor, 1.0); // 限制亮度不超过1.0
            
                return (charCol.a > _Threshold) ? fixed4(blendedColor, charCol.a) : bgCol;
            }
            ENDCG
        }
    }
}