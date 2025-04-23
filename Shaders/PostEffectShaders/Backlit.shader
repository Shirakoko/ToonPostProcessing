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
        
        // Pass 1: 抠图 (原样保留)
        Pass
        {
            Name "CHARACTER_MASK"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
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
            fixed4 _ClearColor;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 character = tex2D(_CharacterTex, i.uv);
                fixed4 background = tex2D(_BackgroundTex, i.uv);
                
                return (character.a > _Threshold) ? _ClearColor : background;
            }
            ENDCG
        }
        
        // Pass 2: 模糊处理
        Pass
        {
            Name "BACKGROUND_BLUR"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
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
            
            sampler2D _MainTex; // 使用标准名称
            float _BlurSize;
            float4 _MainTex_TexelSize;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                // 3x3高斯卷积核权重
                float kernel[9] = {
                    0.077847, 0.123317, 0.077847,
                    0.123317, 0.195346, 0.123317,
                    0.077847, 0.123317, 0.077847
                };
                
                fixed4 color = fixed4(0, 0, 0, 0);
                int index = 0;
                
                // 3x3卷积核采样
                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 offset = float2(x, y) * _MainTex_TexelSize.xy * _BlurSize;
                        fixed4 sample = tex2D(_MainTex, i.uv + offset);
                        color += sample * kernel[index];
                        index++;
                    }
                }
                
                return color;
            }
            ENDCG
        }
        
        // Pass 3: 与角色mask取交集
        Pass
        {
            Name "MASK_INTERSECTION"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
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
            sampler2D _MainTex; // Pass2的结果
            float _Threshold;
            fixed4 _ClearColor;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 character = tex2D(_CharacterTex, i.uv);
                fixed4 blurred = tex2D(_MainTex, i.uv);

                return (character.a > _Threshold) ? blurred : _ClearColor;
            }
            ENDCG
        }
        
        // Pass 4: 最终合成
        Pass
        {
            Name "FINAL_COMPOSITE"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
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
            sampler2D _MaskedBlurTex; // Pass3的结果
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 character = tex2D(_CharacterTex, i.uv);
                fixed4 originalBG = tex2D(_BackgroundTex, i.uv);
                fixed4 maskedBlur = tex2D(_MaskedBlurTex, i.uv);
                
                // 直接合成
                // 绘制背景
                fixed4 final = originalBG;
    
                if (character.a > _Threshold) 
                {
                    // 加法混合（直接提亮）
                    fixed3 additiveBlend = character.rgb + maskedBlur.rgb;
                    
                    // 控制混合程度
                    final.rgb = lerp(character.rgb, additiveBlend, maskedBlur.a);
                }
                
                return final;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}