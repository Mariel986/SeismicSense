#ifndef SEISMIC_SHARED_INCLUDED
#define SEISMIC_SHARED_INCLUDED

#define MAX_WAVES 20

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
    float4 shadowCoord : TEXCOORD4;
};

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
    float4 _Color;
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
ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint i : SV_OutputControlPointID)
{
    return patch[i];
}

float GetInnerNormalizedDistance(int waveIndex)
{
    float normTime = _Timer[waveIndex] / _TimeLimit;
    float width = _Width[waveIndex] / _Range[waveIndex];
    float lowerOffset = 0.2f;
    float peakOffset = 0.5f;
    return (normTime - (peakOffset + lowerOffset) * width) * 0.9f;
}


float GetOuterNormalizedDistance(int waveIndex)
{
    float normTime = _Timer[waveIndex] / _TimeLimit;
    float width = _Width[waveIndex] / _Range[waveIndex];
    float peakOffset = 0.5f;
    float upperOffset = 0.5f;
    return normTime - (peakOffset - upperOffset) * width;
}

bool SegmentIntersectsCircle(float3 a, float3 b, float3 center, float rNorm, float range)
{
    float radius = rNorm * range;

    float3 ab = b - a;
    float3 ac = center - a;

    float t = saturate(dot(ac, ab) / dot(ab, ab));
    float3 closest = a + t * ab;

    float distToCenterSqr = dot(closest - center, closest - center);
    bool closestInside = distToCenterSqr < radius * radius;

    float aDistSqr = dot(a - center, a - center);
    float bDistSqr = dot(b - center, b - center);

    bool aOutside = aDistSqr > radius * radius;
    bool bOutside = bDistSqr > radius * radius;

    return closestInside && (aOutside || bOutside);
}


PatchConstant PatchConstants(InputPatch<ControlPoint, 3> patch)
{
    PatchConstant p;
    bool affected = false;

    // Convert triangle vertices to world space
    float3 v[3];
    for (int i = 0; i < 3; i++)
    {
        v[i] = mul(unity_ObjectToWorld, float4(patch[i].vertex.xyz, 1.0)).xyz;
    }

    // Build triangle edges
    float3 edgeStart[3] = { v[0], v[1], v[2] };
    float3 edgeEnd[3]   = { v[1], v[2], v[0] };

    for (int j = 0; j < _Active; j++)
    {
        float3 center = _SeismicCenter[j];
        float range = _Range[j];

        float inner = GetInnerNormalizedDistance(j);
        float outer = GetOuterNormalizedDistance(j);

        for (int e = 0; e < 3; e++)
        {
            if (SegmentIntersectsCircle(edgeStart[e], edgeEnd[e], center, inner, range) ||
                SegmentIntersectsCircle(edgeStart[e], edgeEnd[e], center, outer, range))
            {
                affected = true;
                break;
            }
        }

        if (affected)
            break;
    }

    float tess = affected ? _TessellationFactor : 1.0;
    p.TessFactor[0] = tess;
    p.TessFactor[1] = tess;
    p.TessFactor[2] = tess;
    p.InsideTess = tess;

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

#endif