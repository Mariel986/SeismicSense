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

// Utility: Interpolate from barycentric weights
float3 BarycentricInterpolate(float3 a, float3 b, float3 c, float3 bary)
{
    return bary.x * a + bary.y * b + bary.z * c;
}

float2 BarycentricInterpolate(float2 a, float2 b, float2 c, float3 bary)
{
    return bary.x * a + bary.y * b + bary.z * c;
}

// Wave shape function
float GetWaveContribution(int j, float3 pos)
{
    float dNorm = length(_SeismicCenter[j] - pos) / _Range[j];
    float tNorm = _Timer[j] / _TimeLimit;
    float dt = tNorm - dNorm;
    float width = _Width[j] / _Range[j];

    float lowerOffset = 0.2f, peakOffset = 0.5f, upperOffset = 0.5f;
    float l = smoothstep((peakOffset - lowerOffset) * width, peakOffset * width, dt);
    float r = 1 - smoothstep(peakOffset * width, (peakOffset + upperOffset) * width, dt);
    float t = l * r;

    return (1 - tNorm) * t * _Height[j];
}

float GetWaveOffsetAt(float3 pos)
{
    float h = 0;
    for (int j = 0; j < _Active; ++j)
    {
        h += GetWaveContribution(j, pos);
    }
    return h;
}

float2 GetWaveGradientAt(float3 pos)
{
    float eps = 0.01;

    float hx1 = GetWaveOffsetAt(pos + float3(eps, 0, 0));
    float hx2 = GetWaveOffsetAt(pos - float3(eps, 0, 0));
    float hz1 = GetWaveOffsetAt(pos + float3(0, 0, eps));
    float hz2 = GetWaveOffsetAt(pos - float3(0, 0, eps));

    float dhdx = (hx1 - hx2) / (2.0 * eps);
    float dhdz = (hz1 - hz2) / (2.0 * eps);

    return float2(dhdx, dhdz);
}

// Tessellation helper
float GetInnerNormalizedDistance(int j)
{
    float tNorm = _Timer[j] / _TimeLimit;
    float width = _Width[j] / _Range[j];
    return (tNorm - (0.5f + 0.2f) * width) * 0.9f;
}

float GetOuterNormalizedDistance(int j)
{
    float tNorm = _Timer[j] / _TimeLimit;
    float width = _Width[j] / _Range[j];
    return tNorm - (0.5f - 0.5f) * width;
}

bool SegmentIntersectsCircle(float3 a, float3 b, float3 center, float rNorm, float range)
{
    float radius = rNorm * range;
    float3 ab = b - a;
    float3 ac = center - a;
    float t = saturate(dot(ac, ab) / dot(ab, ab));
    float3 closest = a + t * ab;
    float distSqr = dot(closest - center, closest - center);

    bool aOutside = dot(a - center, a - center) > radius * radius;
    bool bOutside = dot(b - center, b - center) > radius * radius;
    return distSqr < radius * radius && (aOutside || bOutside);
}

PatchConstant PatchConstants(InputPatch<ControlPoint, 3> patch)
{
    PatchConstant p;
    bool affected = false;

    float3 v[3];
    for (int i = 0; i < 3; ++i)
        v[i] = mul(unity_ObjectToWorld, float4(patch[i].vertex.xyz, 1.0)).xyz;

    float3 edgeStart[3] = { v[0], v[1], v[2] };
    float3 edgeEnd[3]   = { v[1], v[2], v[0] };

    for (int j = 0; j < _Active && !affected; ++j)
    {
        float3 center = _SeismicCenter[j];
        float range = _Range[j];
        float inner = GetInnerNormalizedDistance(j);
        float outer = GetOuterNormalizedDistance(j);

        for (int e = 0; e < 3; ++e)
        {
            if (SegmentIntersectsCircle(edgeStart[e], edgeEnd[e], center, inner, range) ||
                SegmentIntersectsCircle(edgeStart[e], edgeEnd[e], center, outer, range))
            {
                affected = true;
                break;
            }
        }
    }

    float tess = affected ? _TessellationFactor : 1.0f;
    p.TessFactor[0] = tess;
    p.TessFactor[1] = tess;
    p.TessFactor[2] = tess;
    p.InsideTess = tess;
    return p;
}

#endif
