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
            #pragma vertex vert
            #pragma fragment frag_composite

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _CharacterTex;
            sampler2D _BackgroundTex;
            float _Threshold;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag_composite (v2f i) : SV_Target
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
            #pragma vertex vert
            #pragma fragment frag_brightness

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float _BloomThreshold;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag_brightness (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                float brightness = dot(col.rgb, float3(0.2126, 0.7152, 0.0722));
                float bloom = max(0, brightness - _BloomThreshold);
                return col * bloom;
            }
            ENDCG
        }

        // Pass 2: 模糊处理 (高斯模糊)
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag_blur

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _BlurSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag_blur (v2f i) : SV_Target
            {
                // 简单的高斯模糊核
                float weight[3] = {0.227027, 0.316216, 0.070270};
                float2 offsets[3] = {float2(0.0, 0.0), float2(1.0, 0.0), float2(0.0, 1.0)};
                
                fixed4 col = tex2D(_MainTex, i.uv) * weight[0];
                
                for(int idx = 1; idx < 3; idx++)
                {
                    float2 offset = _MainTex_TexelSize.xy * offsets[idx] * _BlurSize;
                    col += tex2D(_MainTex, i.uv + offset) * weight[idx];
                    col += tex2D(_MainTex, i.uv - offset) * weight[idx];
                }
                
                return col;
            }
            ENDCG
        }

        // Pass 3: 最终合成
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag_final

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;       // 合成后的场景
            sampler2D _BloomTex;      // 模糊后的高光
            float _BloomIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag_final (v2f i) : SV_Target
            {
                fixed4 sceneCol = tex2D(_MainTex, i.uv);
                fixed4 bloomCol = tex2D(_BloomTex, i.uv);
                
                // 使用变亮混合模式 (Screen模式) 合成Bloom效果
                fixed3 result = 1.0 - (1.0 - sceneCol.rgb) * (1.0 - bloomCol.rgb * _BloomIntensity);
                
                return fixed4(result, sceneCol.a);
            }
            ENDCG
        }
    }
}