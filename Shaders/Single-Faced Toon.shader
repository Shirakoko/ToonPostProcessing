Shader "Custom/Single-Faced Toon"
{
	Properties
	{
		[Header(Main)]
		_MainTex ("Texture", 2D) = "white" {}
		_Color ("Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_ShadowColor ("ShadowColor", Color) = (1.0, 1.0, 1.0, 1.0)
		_RimColor ("RimColor", Color) = (1.0, 1.0, 1.0, 1.0)
		_ShadowThreshold ("ShadowThreshold", Range(-1.0, 1.0)) = 0.2
		_RimThreshold ("RimThreshold", Range(0.0, 1.0)) = 1
		_RimPower ("RimPower", Range(0.0, 16)) = 4.0
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_SpecularScale("Specular Scale", Range(0, 0.1)) = 0.02
		_EdgeSmoothness("Edge Smoothness", Range(0,2)) = 2
		_Outline("Outline",Range(0,1))=0.1
		_OutlineColor("OutlineColor",Color)=(0,0,0,1)
	}
	SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        // Pass 0: 计算 diffuse 并存入 RenderTexture
        Pass
        {
			Name "DIFFUSE_PREPASS"
			Blend Off       // 禁用混合，直接覆盖
			ZWrite On       // 启用深度写入
			ZTest LEqual    // 仅渲染未被遮挡的像素（默认值）
			Cull Back
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                fixed4 color : COLOR;
            };

            struct v2f
            {
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            fixed _ShadowThreshold;
            half _EdgeSmoothness;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }
            
            fixed frag (v2f i) : SV_Target
            {
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                
                fixed diffValue = dot(worldNormal, worldLightDir);
                fixed w = fwidth(diffValue) * _EdgeSmoothness;
                fixed diffStep = smoothstep(-w+_ShadowThreshold, w+_ShadowThreshold, diffValue);
                
                return diffStep; // 输出到 RenderTexture
            }
            ENDCG
        }

        // Pass 1: 主渲染（从 RenderTexture 读取 diffuse）
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode"="ForwardBase" }
			ZWrite On
			ZTest LEqual  // 与 DIFFUSE_PREPASS 一致
			Cull Back
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                fixed4 color : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float4 vertex : SV_POSITION;
                fixed4 color : COLOR;
                UNITY_FOG_COORDS(3)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color, _ShadowColor, _RimColor;
            fixed _RimThreshold;
            half _RimPower;
            fixed4 _Specular;
            fixed _SpecularScale;
            half _EdgeSmoothness;

            // 声明用于存储 diffuse 的 RenderTexture
            sampler2D _DiffuseRT;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.color = v.color;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);
 
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed spec = dot(worldNormal, worldHalfDir)+(i.color.g-0.5)*2;
                fixed w = fwidth(spec)*_EdgeSmoothness;
                
                fixed4 specular = _Specular * lerp(0,1,smoothstep(-w,w,spec*0.5-0.5)) * step(0.05, _SpecularScale);
                
                // 从 RenderTexture 读取 diffuse 值
                fixed diffStep = tex2D(_DiffuseRT, i.vertex.xy / _ScreenParams.xy).r;
                
                fixed4 light = _LightColor0 * 0.5 + 0.5;
                fixed4 diffuse = light * col * (diffStep + (1 - diffStep) * _ShadowColor) * _Color;
                
                fixed rimValue = pow(1 - dot(worldNormal, worldViewDir), _RimPower);
                fixed rimStep = smoothstep(-w+_RimThreshold, w+_RimThreshold, rimValue);
                
                fixed4 rim = light * rimStep * 0.5 * diffStep * _RimColor;
                fixed4 final = diffuse + rim + specular;
 
                UNITY_APPLY_FOG(i.fogCoord, final);
                return final;
            }
            ENDCG
        }

        // Pass 2: 描边（保持不变）
        Pass
        {	
            name "OUTLINE"
            Cull Front
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                UNITY_FOG_COORDS(0)
                float4 pos : SV_POSITION;
            };

            float _Outline;
            fixed4 _OutlineColor;
            
            v2f vert (appdata v)
            {
                v2f o;
                float3 vNormal = COMPUTE_VIEW_NORMAL;
                float2 pNormalXY = TransformViewToProjection(vNormal).xy;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.pos.xy += pNormalXY * _Outline * 0.01; 
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_APPLY_FOG(i.fogCoord, col);
                return _OutlineColor;
            }
            ENDCG
        }
    }
}