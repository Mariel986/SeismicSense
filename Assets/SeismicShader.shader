Shader "Custom/SeismicShader"
{
    Properties
    {
        _MainColor ("Main Color", Color) = (.25, .5, .5, 1)
        _TessellationFactor ("Tessellation Factor", Range(1, 64)) = 8
    }
    SubShader
    {
        Tags { 
            "RenderType"="Opaque" 
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100

        Pass
        {
            Cull Off
 
            HLSLPROGRAM 

            #pragma target 5.0

            #pragma shader_feature _ SEISMIC_TRANSPARENT
            #pragma shader_feature _ SEISMIC_DISPLACEMENT

            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct ControlPoint
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct PatchConstant
            {
                float TessFactor[3] : SV_TESSFACTOR;
                float InsideTess : SV_INSIDETESSFACTOR;
            };

            struct Interpolators
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 offset : TEXCOORD2;
                float3 normal : TEXCOORD3;
            };

            #define MAX_WAVES 20

            CBUFFER_START(UnityPerMaterial)
                sampler2D _MainTex;
                float4 _MainTex_ST;
                float4 _MainColor, _WaveColor[MAX_WAVES];
                float3 _SeismicCenter[MAX_WAVES];
                float _TimeLimit;
                float _Range[MAX_WAVES], _Width[MAX_WAVES], _Timer[MAX_WAVES];
                int _Active;

                float _Height[MAX_WAVES];
                int _TessellationFactor;
            CBUFFER_END

            ControlPoint vert(Appdata v) 
            {
                ControlPoint o;
                o.vertex = v.vertex;
                o.normal = v.normal;
                o.uv = v.uv;
                return o;
            }
            [domain("tri")]
            [partitioning("integer")]
            [outputtopology("triangle_cw")]
            [outputcontrolpoints(3)]
            [patchconstantfunc("PatchConstants")]
            ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint i : SV_OUTPUTCONTROLPOINTID)
            {
                return patch[i];
            }

            PatchConstant PatchConstants(InputPatch<ControlPoint, 3> patch)
            {
                PatchConstant p;
                p.TessFactor[0] = _TessellationFactor;
                p.TessFactor[1] = _TessellationFactor;
                p.TessFactor[2] = _TessellationFactor;
                p.InsideTess = _TessellationFactor;
                return p;
            }

            float GetWaveOffsetAt(float3 samplePos)
            {
                float h = 0;
                for (int j = 0; j < _Active; j++)
                {
                    float dNorm = length(_SeismicCenter[j] - samplePos) / _Range[j];
                    float tNorm = _Timer[j] / _TimeLimit;
                    float dt = tNorm - dNorm;
                    float width = _Width[j] / _Range[j];

                    float lowerOffset = 0.2f, peakOffset = 0.5f, upperOffset = 0.5f;
                    float l = smoothstep((peakOffset - lowerOffset) * width, peakOffset * width, dt);
                    float r = 1 - smoothstep(peakOffset * width, (peakOffset + upperOffset) * width, dt);
                    float t = l * r;

                    h += (1 - tNorm) * t * _Height[j];
                }
                return h;
            }

            [domain("tri")]
            Interpolators domain(PatchConstant p, const OutputPatch<ControlPoint, 3> patch, float3 bary : SV_DomainLocation)
            {
                Interpolators o;

                float3 pos =    
                    bary.x * patch[0].vertex.xyz + 
                    bary.y * patch[1].vertex.xyz + 
                    bary.z * patch[2].vertex.xyz;
                float3 norm = normalize(
                    bary.x * patch[0].normal + 
                    bary.y * patch[1].normal + 
                    bary.z * patch[2].normal
                    );
                float2 uv = 
                    bary.x * patch[0].uv + 
                    bary.y * patch[1].uv + 
                    bary.z * patch[2].uv;

                #if defined(SEISMIC_DISPLACEMENT)
                    float3 worldPos = TransformObjectToWorld(pos);
                    float3 worldNormal = TransformObjectToWorldNormal(norm);

                    float height = GetWaveOffsetAt(worldPos);
                    float3 offset = worldNormal * height;
                    worldPos += offset;

                    o.vertex = TransformWorldToHClip(worldPos);
                    o.offset = offset;
                    o.worldPos = worldPos;

                    float eps = 0.01;

                    float3 wpX = worldPos + float3(eps, 0, 0);
                    float3 wpZ = worldPos + float3(0, 0, eps);

                    float3 dispX = GetWaveOffsetAt(wpX);
                    float3 dispZ = GetWaveOffsetAt(wpZ);

                    float3 dx = normalize(float3(eps, dispX.y - offset.y, 0));
                    float3 dz = normalize(float3(0, dispZ.y - offset.y, eps));

                    float3 recalculatedNormal = normalize(cross(dz, dx));

                    o.normal = recalculatedNormal;
                #else
                    float3 worldPos = TransformObjectToWorld(pos);
                    o.vertex = TransformWorldToHClip(worldPos);
                    o.offset = float3(0, 0, 0);
                    o.normal = norm;
                    o.worldPos = worldPos;
                #endif

                o.uv = TRANSFORM_TEX(uv, _MainTex);
                return o;
            }

            float4 frag (Interpolators i) : SV_Target
            {
                float4 col = _MainColor;
                float lowerOffset = 0.2f, peakoffset = 0.5f, upperoffset = 0.5f;

                for(int j = 0; j < _Active; j++) {
                    
                    #if defined(SEISMIC_DISPLACEMENT)
                        float normalDistance = length(_SeismicCenter[j] - (i.worldPos - i.offset)) / _Range[j];
                    #else
                        float normalDistance = length(_SeismicCenter[j] - (i.worldPos)) / _Range[j];
                    #endif
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
                #if defined(SEISMIC_TRANSPARENT)
                    if(col.x < 0.02f) discard;
                #endif
                return col;    
                //return float4(i.normal * 0.5f + 0.5f, 1.0f);   

            }
            ENDHLSL
        }
    }
}
