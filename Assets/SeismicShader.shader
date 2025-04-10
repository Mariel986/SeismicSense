Shader "Unlit/SeismicShader"
{
    Properties
    {
        _MainColor ("Main Color", Color) = (.25, .5, .5, 1)
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
            float4 _MainColor, _WaveColor[MAX_WAVES];
            float3 _SeismicCenter[MAX_WAVES];
            float _TimeLimit;
            float _Range[MAX_WAVES], _Width[MAX_WAVES], _Timer[MAX_WAVES];
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
                float lowerOffset = 0.2f, peakoffset = 0.5f, upperoffset = 0.5f;

                for(int j = 0; j < _Active; j++) {
                    float3 center = _SeismicCenter[j];
                    float distance = length(center - i.worldPos);
                    float normalDistance = distance / _Range[j];
                    float normalTime = _Timer[j] / _TimeLimit;

                    float dt = normalTime - normalDistance;
                    float width = _Width[j] / _Range[j];
                    float left = smoothstep( (peakoffset - lowerOffset) * width , peakoffset * width, dt);
                    float right = 1 - smoothstep(peakoffset * width, (peakoffset + upperoffset) * width, dt);
                    float t = left * right;

                    float4 nextColor = lerp(_MainColor, _WaveColor[j] * (1 - normalTime), t);
                    col = col + nextColor;
                }
                col = saturate(col);
                //if(col.x < 0.02f) discard;
                return col;
            }
            ENDCG
        }
    }
}
