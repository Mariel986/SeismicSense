Shader "Unlit/SeismicShader"
{
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
        _MainColor ("Main Color", Color) = (.25, .5, .5, 1)
        _SecondaryColor ("Main Color", Color) = (.25, .5, .5, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Cull Off

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
                float3 worldPos : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            #define MAX_WAVES 20

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _MainColor, _SecondaryColor;
            float3 _SeismicCenter[MAX_WAVES];
            float _Timer[MAX_WAVES];
            float _Range;
            int _Active;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = _MainColor;

                for(int j = 0; j < _Active; j++) {
                    float3 center = _SeismicCenter[j];
                    float distance = length(center - i.worldPos);
                    float t = abs(distance - _Timer[j]) * 8;// / (distance);
                    float4 nextColor = lerp(_SecondaryColor, _MainColor, saturate(t));
                    nextColor /= (distance * _Range + 1);
                    col = max(col, nextColor);
                }
                col = saturate(col);
                if(col.x < 0.02f) discard;
                return col;
            }
            ENDCG
        }
    }
}
