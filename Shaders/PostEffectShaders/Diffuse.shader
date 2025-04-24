Shader "Hidden/Diffuse"
{
    Properties
    {
        _CharacterTex ("Character Texture", 2D) = "black" {}
        _BackgroundTex ("Background Texture", 2D) = "black" {}
        _Threshold ("Alpha Threshold", Range(0,1)) = 0.1
        
        // Diffuse效果参数
        _BloomIntensity("Bloom Intensity", Range(0, 1)) = 0.5
        _BloomThreshold("Bloom Threshold", Range(0, 1)) = 0.7
        _BlurSize("Blur Size", Range(0, 0.01)) = 0.1
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

        // Pass 1: 提取高光部分
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_brightness
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float _BloomThreshold;

            fixed4 frag_brightness (v2f_img i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                float brightness = dot(col.rgb, float3(0.2126, 0.7152, 0.0722));
                float bloom = max(0, brightness - _BloomThreshold);
                return col * bloom;
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
            float4 _MainTex_TexelSize;
            float _BlurSize;

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

        // Pass 3: 最终合成
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag_final
            #include "UnityCG.cginc"

            sampler2D _MainTex;       // 合成后的场景
            sampler2D _BloomTex;      // 模糊后的高光
            float _BloomIntensity;

            fixed4 frag_final (v2f_img i) : SV_Target
            {
                fixed4 sceneCol = tex2D(_MainTex, i.uv);
                fixed4 bloomCol = tex2D(_BloomTex, i.uv);
                
                // 使用变亮混合模式 (Screen模式) 叠加
                fixed3 result = 1.0 - (1.0 - sceneCol.rgb) * (1.0 - bloomCol.rgb * _BloomIntensity);
                
                return fixed4(result, sceneCol.a);
            }
            ENDCG
        }
    }
}