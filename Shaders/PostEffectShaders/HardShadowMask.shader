Shader "Hidden/HardShadowMask"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" "ShadowCaster"="True" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 计算兰伯特值 (N·L)
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                float lambert = dot(worldNormal, worldLightDir);

                // 二值化阴影（阈值可调）
                float shadow = step(0.2, lambert); // >0.2为1（白），否则为0（黑）
                return shadow;
            }
            ENDCG
        }
    }
}