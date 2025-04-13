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

#endif