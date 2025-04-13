Shader "Custom/TessellatedSurface"
{
    Properties
    {
        _Color ("Base Color", Color) = (1,1,1,1)
        _TessellationUniform ("Tessellation Factor", Range(1,64)) = 4
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 400

        Pass
        {
            Name "TessellationPass"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma target 5.0
            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag
            #pragma require tessellation

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct tessellationControlPoint
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct hsconstant
            {
                float TessFactor[3] : SV_TessFactor;
                float InsideTessFactor : SV_InsideTessFactor;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float3 normal : TEXCOORD0;
            };

            float _TessellationUniform;
            float4 _Color;

            // Vertex Shader
            tessellationControlPoint vert(appdata v)
            {
                tessellationControlPoint o;
                o.vertex = v.vertex;
                o.normal = v.normal;
                return o;
            }

            // Hull Shader (Tessellation Control Shader)
            [domain("tri")]
            [partitioning("integer")]
            [outputtopology("triangle_cw")]
            [outputcontrolpoints(3)]
            [patchconstantfunc("HSConstants")]
            tessellationControlPoint hull(InputPatch<tessellationControlPoint, 3> patch, uint i : SV_OutputControlPointID)
            {
                return patch[i];
            }

            // Patch Constants Function
            hsconstant HSConstants(InputPatch<tessellationControlPoint, 3> patch)
            {
                hsconstant o;
                o.TessFactor[0] = _TessellationUniform;
                o.TessFactor[1] = _TessellationUniform;
                o.TessFactor[2] = _TessellationUniform;
                o.InsideTessFactor = _TessellationUniform;
                return o;
            }

            // Domain Shader (Tessellation Evaluation Shader)
            [domain("tri")]
            v2f domain(hsconstant hsConst, const OutputPatch<tessellationControlPoint, 3> patch, float3 bary : SV_DomainLocation)
            {
                v2f o;
                float3 pos = bary.x * patch[0].vertex.xyz +
                             bary.y * patch[1].vertex.xyz +
                             bary.z * patch[2].vertex.xyz;

                float3 norm = normalize(bary.x * patch[0].normal +
                                        bary.y * patch[1].normal +
                                        bary.z * patch[2].normal);

                o.position = TransformObjectToHClip(float4(pos, 1.0));
                o.normal = norm;
                return o;
            }

            // Fragment Shader
            half4 frag(v2f i) : SV_Target
            {
                return half4(normalize(i.normal) * 0.5 + 0.5, 1.0); // normal visualization
            }

            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
