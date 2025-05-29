Shader "Custom/SeismicShader"
{
    Properties
    {        
        _Color ("Base Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _TessellationFactor ("Tessellation Factor", Range(1, 128)) = 8
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }

        LOD 100

        Pass
        {
            Name "ForwardLit"
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
            ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint i : SV_OutputControlPointID)
            {
                return patch[i];
            }

            [domain("tri")]
            Interpolators domain(PatchConstant p, const OutputPatch<ControlPoint, 3> patch, float3 bary : SV_DomainLocation)
            {
                Interpolators o;

                float3 pos = BarycentricInterpolate(
                    patch[0].vertex.xyz, patch[1].vertex.xyz, patch[2].vertex.xyz, bary);
                float3 normal = normalize(BarycentricInterpolate(
                    patch[0].normal, patch[1].normal, patch[2].normal, bary));
                float2 uv = BarycentricInterpolate(
                    patch[0].uv, patch[1].uv, patch[2].uv, bary);

                float3 worldPos = TransformObjectToWorld(pos);
                float3 worldNormal = normalize(TransformObjectToWorldNormal(normal));

                #if defined(SEISMIC_DISPLACEMENT)
                    float height = GetWaveOffsetAt(worldPos);
                    float3 displaced = worldPos + worldNormal * height;
                    o.vertex = TransformWorldToHClip(displaced);
                    o.worldPos = displaced;
                    o.offset = displaced - worldPos;
                #else
                    o.vertex = TransformWorldToHClip(worldPos);
                    o.worldPos = worldPos;
                    o.offset = float3(0, 0, 0);
                #endif

                o.normal = worldNormal;
                o.uv = TRANSFORM_TEX(uv, _MainTex);
                return o;
            }

            float4 frag(Interpolators i) : SV_Target
            {
                float4 col = _MainColor;
                float3 basePos = i.worldPos - i.offset;

                for (int j = 0; j < _Active; j++)
                {
                    float normalDist = length(_SeismicCenter[j] - basePos) / _Range[j];
                    float timeNorm = _Timer[j] / _TimeLimit;
                    float dt = timeNorm - normalDist;
                    float width = _Width[j] / _Range[j];

                    float l = smoothstep((0.5 - 0.2) * width, 0.5 * width, dt);
                    float r = 1 - smoothstep(0.5 * width, (0.5 + 0.5) * width, dt);
                    float t = l * r;

                    float4 waveColor = lerp(_Color, _WaveColor[j] * (1 - timeNorm), t);
                    col += waveColor;
                }

                col = saturate(col);

                #if defined(SEISMIC_LIGHTING)
                    float2 grad = GetWaveGradientAt(basePos);

                    float3 dX = float3(1, grad.x, 0);
                    float3 dZ = float3(0, grad.y, 1);

                    float3 slopeNormal = normalize(cross(dZ, dX));
                    float3 normal = normalize(lerp(i.normal, slopeNormal, 0.85)); // Blend with geometric normal


                    float3 lightDir = normalize(GetMainLight().direction);
                    float NdotL = max(0.0, dot(normal, lightDir));
                    float halfLambert = NdotL * 0.5 + 0.5;

                    float3 surfaceColor = tex2D(_MainTex, i.uv).rgb;
                    float4 shadowCoord = TransformWorldToShadowCoord(i.worldPos);
                    float shadow = MainLightRealtimeShadow(shadowCoord);
                    shadow = lerp(0.25, 1.0, shadow); // soften shadow

                    float3 ambient = float3(0.1, 0.1, 0.1);
                    float3 lit = surfaceColor * (_MainLightColor.rgb * halfLambert * shadow + ambient);

                    return float4(lit, col.a);
                #else
                    #if defined(SEISMIC_TRANSPARENT)
                        if (col.a < 0.02f) discard;
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

            struct ShadowVaryings { float4 positionCS : SV_POSITION; };

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
            ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint i : SV_OutputControlPointID)
            {
                return patch[i];
            }

            [domain("tri")]
            ShadowVaryings domainShadow(PatchConstant p, const OutputPatch<ControlPoint, 3> patch, float3 bary : SV_DomainLocation)
            {
                ShadowVaryings o;
                float3 pos = BarycentricInterpolate(
                    patch[0].vertex.xyz, patch[1].vertex.xyz, patch[2].vertex.xyz, bary);
                float3 normal = normalize(BarycentricInterpolate(
                    patch[0].normal, patch[1].normal, patch[2].normal, bary));

                float3 worldPos = TransformObjectToWorld(pos);
                #if defined(SEISMIC_DISPLACEMENT)
                    float3 worldNormal = normalize(TransformObjectToWorldNormal(normal));
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
