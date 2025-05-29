Shader "Custom/SeismicShader"
{
    Properties
    {        
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _TessellationFactor ("Tessellation Factor", Range(1, 128)) = 8
    }
    SubShader
    {
        Tags { 
            "RenderType"="Opaque" 
            "Queue"="Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100

        Pass
        {
            Cull Off
 
            HLSLPROGRAM 

            #pragma target 5.0
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            #pragma shader_feature _ SEISMIC_TRANSPARENT
            #pragma shader_feature _ SEISMIC_DISPLACEMENT
            #pragma shader_feature _ SEISMIC_LIGHTING

            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Seismic.hlsl"

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
                    float3 samplePos = TransformObjectToWorld(pos);
                    float3 worldNormal = TransformObjectToWorldNormal(norm);

                    float height = GetWaveOffsetAt(samplePos);
                    float3 offset = worldNormal * height;

                    o.worldPos = samplePos + offset;
                    o.vertex = TransformWorldToHClip(o.worldPos);
                    o.offset = offset;

                    float eps = 0.01;

                    float dispX = GetWaveOffsetAt(samplePos + float3(eps, 0, 0));
                    float dispZ = GetWaveOffsetAt(samplePos + float3(0, 0, eps));

                    float3 dx = float3(eps, dispX - height, 0);
                    float3 dz = float3(0, dispZ - height, eps);

                    float3 recalculatedNormal = normalize(cross(dz, dx));

                    o.normal = recalculatedNormal;
                #else
                    float3 worldPos = TransformObjectToWorld(pos);
                    o.vertex = TransformWorldToHClip(worldPos);
                    o.offset = float3(0, 0, 0);
                    o.normal = TransformObjectToWorldNormal(norm);
                    o.worldPos = worldPos;
                #endif

                o.uv = TRANSFORM_TEX(uv, _MainTex);
                o.shadowCoord = TransformWorldToShadowCoord(o.worldPos);

                return o;
            }

            /*float4 frag(Interpolators i) : SV_Target
            {
                float4 col = float4(0, 0, 0, 1);

                for (int j = 0; j < _Active; j++)
                {
                    float dNorm = length(_SeismicCenter[j] - i.worldPos) / _Range[j];

                    // Use fixed helper functions
                    float inner = GetInnerNormalizedDistance(j);
                    float outer = GetOuterNormalizedDistance(j);

                    // Simple hard red band test
                    if (dNorm >= inner && dNorm <= outer)
                    {
                        col.rgb += float3(1, 0, 0);
                    }
                }

                return saturate(col);
            }*/
            float4 frag (Interpolators i) : SV_Target
            {
                float4 col = _MainColor;
                float lowerOffset = 0.2f, peakoffset = 0.5f, upperoffset = 0.5f;

                for(int j = 0; j < _Active; j++) {
                    
                    float normalDistance = length(_SeismicCenter[j] - (i.worldPos - i.offset)) / _Range[j];
                    float normalTime = _Timer[j] / _TimeLimit;

                    float dt = normalTime - normalDistance;
                    float width = _Width[j] / _Range[j];
                    float left = smoothstep( (peakoffset - lowerOffset) * width , peakoffset * width, dt);
                    float right = 1 - smoothstep(peakoffset * width, (peakoffset + upperoffset) * width, dt);
                    float t = left * right;

                    float4 nextColor = lerp(_Color, _WaveColor[j] * (1 - normalTime), t);
                    col = col + nextColor;
                }
                col = saturate(col);



                #if defined(SEISMIC_LIGHTING)
                    // Lighting
                    Light mainLight = GetMainLight();

                    float3 lightDir = normalize(mainLight.direction);
                    float NdotL = dot(normalize(i.normal), lightDir);
                    float halfLambert = NdotL * 0.5 + 0.5;

                    float3 surfaceColor = tex2D(_MainTex, i.uv).rgb;
                    //float shadow = MainLightRealtimeShadow(i.shadowCoord);
                    float shadow = 1.0f;

                    float3 litColor = surfaceColor * _MainLightColor.rgb * halfLambert * shadow;
                    return float4(litColor, col.a);
                    //return float4(i.normal, 1.0f);  
                #else
                    #if defined(SEISMIC_TRANSPARENT)
                        if(col.a < 0.02f) discard;
                    #endif
                    return col;
                #endif
            }
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            Cull Off

            HLSLPROGRAM
            #pragma target 5.0

            #pragma vertex vert
            #pragma hull hull
            #pragma domain domainShadow
            #pragma fragment fragShadow

            #pragma shader_feature _ SEISMIC_DISPLACEMENT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            #include "Seismic.hlsl"

            struct ShadowVaryings
            {
                float4 positionCS : SV_POSITION;
            };

            [domain("tri")]
            ShadowVaryings domainShadow(PatchConstant p, const OutputPatch<ControlPoint, 3> patch, float3 bary : SV_DomainLocation)
            {
                ShadowVaryings o;

                float3 pos = bary.x * patch[0].vertex.xyz +
                            bary.y * patch[1].vertex.xyz +
                            bary.z * patch[2].vertex.xyz;

                float3 worldPos = TransformObjectToWorld(pos);

                #if defined(SEISMIC_DISPLACEMENT)
                    float3 normal = normalize(
                        bary.x * patch[0].normal +
                        bary.y * patch[1].normal +
                        bary.z * patch[2].normal
                    );
                    float3 worldNormal = TransformObjectToWorldNormal(normal);
                    float height = GetWaveOffsetAt(worldPos);
                    worldPos += worldNormal * height;
                #endif

                o.positionCS = TransformWorldToHClip(worldPos);
                return o;
            }

            float4 fragShadow(ShadowVaryings i) : SV_Target
            {
                return 0;
            }

            ENDHLSL
        }

    }
}
