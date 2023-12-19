#include <metal_stdlib>
#include "../Common.metal"

using namespace metal;

struct ContourPathVertexOutput {
    float4 position [[ position ]];
    float t;
};

float2 perpendicular(float2 a, float2 b)
{
    const float2 dir = normalize(b - a);
    return float2(-dir.y, dir.x);
}

vertex ContourPathVertexOutput
contourPathVertexShader(
                        constant const float2* points [[ buffer(0) ]],
                        constant const int& pointsCount [[ buffer(1) ]],
                        constant const float& time [[ buffer(2) ]],
                        constant const float3x3& uMatrix [[ buffer(3) ]],
                        constant const float3x3& invUMatrix [[ buffer(4) ]],
                        constant const float& lineThikness [[ buffer(5) ]],
                        constant const uint& verticesCount [[buffer(6)]],
                        const uint vid [[vertex_id]],
                        const uint iid [[instance_id]]
                        )
{
    const bool isTopIndex = vid % 2;
    const float halfLineThikness = lineThikness / 2.0;

    const uint steps = verticesCount / 2;
    const float t = float(vid / 2) / float(steps - 1);

    constant const float2 *line = points + iid * 2;
    const float2 start = line[0];
    const float2 mid = line[1];
    const float2 end = line[2];

    const float2 start_p = perpendicular(start, mid);
    const float2 mid_p = perpendicular(mid, end);
    const float2 end_p = perpendicular(end, line[4 % pointsCount]);
//    mid_p = sign(start_p) * abs(mid_p);
    const float2 perpend = mix(start_p, mid_p, t);

    const float2 start2mid = mid - start;
    const float2 start2end = end - start;

    float2 position = start + mix(start2mid, start2end, t) * t;
    position += (isTopIndex ? 1.0 : -1.0) * perpend * halfLineThikness;
    position = makeXYVertex(position, uMatrix, invUMatrix);

    ContourPathVertexOutput out;
    out.position = float4(position, 0, 1);
    out.t = t;

    return out;
}

fragment float4
contourPathFragmentShader(ContourPathVertexOutput in [[stage_in]])
{
    return float4(1, 0, 0, 1);
}
