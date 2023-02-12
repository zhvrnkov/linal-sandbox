//
//  Plot.metal
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 1/17/23.
//

#include <metal_stdlib>
#include "../Common.metal"

using namespace metal;

struct LinePlotVertexOutput {
    float4 position [[ position ]];
};

vertex LinePlotVertexOutput
line_plot_vertex(
                 constant const float2* points [[ buffer(0) ]],
                 constant const int& pointsCount [[ buffer(1) ]],
                 constant const float& time [[ buffer(2) ]],
                 constant const float3x3& uMatrix [[ buffer(3) ]],
                 constant const float3x3& invUMatrix [[ buffer(4) ]],
                 constant const float& lineThikness [[ buffer(5) ]],
                 const uint vid [[ vertex_id ]]
                 )
{
    const uint lineIndex = vid / 4;
    const uint pointIndex = lineIndex + (vid % 4 / 2);
    const bool isTopIndex = vid % 2;
    
    float2 perpendicular;
    {
        const float2 basePoint = points[lineIndex];
        const float2 topPoint = points[lineIndex + 1];
        const float2 dir = normalize(topPoint - basePoint);
        perpendicular = float2(-dir.y, dir.x);
    }
    
    const float halfLineThikness = lineThikness / 2.0;
    float2 position = points[pointIndex];
    position += (isTopIndex ? 1.0 : -1.0) * perpendicular * halfLineThikness;
    position = makeXYVertex(position, uMatrix, invUMatrix);
    
    LinePlotVertexOutput out;
    out.position = float4(position, 0, 1);
    
    return out;
}

fragment float4
line_plot_fragment(
                   LinePlotVertexOutput vin [[ stage_in ]],
                   constant const float4& color [[ buffer(0) ]]
                   )
{
    return color;
}
