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

        // Pass 1: 根据_DiffuseRT硬阴影得到纯白色硬暗部
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag_separate

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
            sampler2D _DiffuseRT;
            fixed4 _ClearColor;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag_separate (v2f i) : SV_Target
            {
                fixed4 charCol = tex2D(_CharacterTex, i.uv);
                float diffuseCol = tex2D(_DiffuseRT, i.uv).r;
                
                // 如果在阴影遮罩内，返回颜色，否则返回透明
                fixed4 result = (diffuseCol == 0.0) ? fixed4(1,1,1,1) : _ClearColor;
                return result;
            }
            ENDCG
        }

        // Pass 2: 生成纯白模糊阴影遮罩
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag_shadow_mask

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

            fixed4 frag_shadow_mask (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

                // 高斯模糊
                float weight[3] = {0.227027, 0.316216, 0.070270};
                float2 offsets[3] = {float2(0.0, 0.0), float2(1.0, 0.0), float2(0.0, 1.0)};
                
                fixed4 blurredCol = col * weight[0];
                
                for(int idx = 1; idx < 3; idx++)
                {
                    float2 offset = _MainTex_TexelSize.xy * offsets[idx] * _BlurSize;
                    blurredCol += tex2D(_MainTex, i.uv + offset) * weight[idx];
                    blurredCol += tex2D(_MainTex, i.uv - offset) * weight[idx];
                }
                
                return blurredCol;
            }
            ENDCG
        }

        // Pass 4: 合成阴影并取反alpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag_shadow_alpha

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

            fixed4 _ShadowColor;
            sampler2D _ShadowMaskTex; // Pass2的输出 (模糊遮罩)

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag_shadow_alpha (v2f i) : SV_Target
            {
                fixed4 maskCol = tex2D(_ShadowMaskTex, i.uv);
                
                // 使用遮罩的alpha控制白色强度
                fixed4 result = lerp(fixed4(0,0,0,0), _ShadowColor, maskCol.a);
                result.a = 1.0 - result.a;
                return result;
            }
            ENDCG
        }

        // Pass 4: 最终合成 (Screen模式)
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

            sampler2D _CharacterTex;  // 角色纹理
            sampler2D _BackgroundTex; // 背景纹理
            sampler2D _ShadowTex;     // Pass3的输出 (带alpha的阴影)
            float _Threshold;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag_final (v2f i) : SV_Target
            {
                fixed4 charCol = tex2D(_CharacterTex, i.uv); // 角色颜色
                fixed4 shadowCol = tex2D(_ShadowTex, i.uv); // 阴影颜色（RGB）和透明度（A）
                fixed4 bgCol = tex2D(_BackgroundTex, i.uv); // 背景颜色
                
                // Multiply + Add 混合
                fixed3 blendedColor = charCol.rgb * (1.0 + shadowCol.rgb * shadowCol.a);
                blendedColor = min(blendedColor, 1.0); // 限制亮度不超过1.0
            
                return (charCol.a > _Threshold) ? fixed4(blendedColor, charCol.a) : bgCol;
            }
            ENDCG
        }
    }
}