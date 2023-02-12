//
//  Plot.metal
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 1/17/23.
//

#include <metal_stdlib>
#include "../Common.metal"

using namespace metal;

struct DotsPlotVertexOutput {
    float4 position [[ position ]];
    float2 coord;
};

vertex DotsPlotVertexOutput
dots_plot_vertex(
                 constant const float2* points [[ buffer(0) ]],
                 constant const int& pointsCount [[ buffer(1) ]],
                 constant const float& time [[ buffer(2) ]],
                 constant const float3x3& uMatrix [[ buffer(3) ]],
                 constant const float3x3& invUMatrix [[ buffer(4) ]],
                 constant const float& radius [[ buffer(5) ]],
                 const uint vid [[ vertex_id ]],
                 const uint iid [[ instance_id ]]
                 )
{
    float2 position = makeXYVertex(points[iid], uMatrix, invUMatrix);
    const float2 coord = float2(vid / 2 ? -1 : 1, vid % 2 ? 1 : -1);
    position += coord * radius;
    
    DotsPlotVertexOutput out;
    out.position = float4(position, 0, 1);
    out.coord = coord;
    
    return out;
}

fragment float4
dots_plot_fragment(
                   DotsPlotVertexOutput vin [[ stage_in ]],
                   constant const float4& color [[ buffer(0) ]]
                   )
{
    constexpr float radiusInNormalizedSpace = 1.0;
    return color * (length(vin.coord.xy) < radiusInNormalizedSpace);
}
