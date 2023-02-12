//
//  Field.metal
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 2/1/23.
//

#include <metal_stdlib>
#include "../Common.metal"
using namespace metal;

struct ArrowVertexOutput {
    float4 position [[ position ]];
    float4 arrow;
};

constant constexpr float2 offsets[] = {
    float2(1,  0),   float2(-1,  0),
    float2(1, 0.75), float2(-1, 0.75),
    float2(2, 0.75), float2(-2, 0.75),
    float2(0, 1)
};

vertex ArrowVertexOutput
arrows_vertex(
              constant const float4* arrows [[ buffer(0) ]],
              constant const int& arrowsCount [[ buffer(1) ]],
              constant const float3x3& uMatrix [[ buffer(2) ]],
              constant const float3x3& invUMatrix [[ buffer(3) ]],
              constant const float& lineThikness [[ buffer(4) ]],
              const uint iid [[ instance_id ]],
              const uint vid [[ vertex_id ]]
              )
{
    const float4 arrow = arrows[iid];
    const float2 arrowTail = makeXYVertex(arrow.xy, uMatrix, invUMatrix);
    const float2 arrowHead = makeXYVertex(arrow.zw, uMatrix, invUMatrix);
    
    const float2 direction = arrowHead - arrowTail;
    const float2 directionPerp = perpendicular(direction);
    
    const float3 ix = float3(lineThikness * normalize(directionPerp), 0);
    const float3 iy = float3(direction, 0);
    const float3 iz = float3(arrowTail, 1);
    const float3x3 t = float3x3(ix, iy, iz);
    
    ArrowVertexOutput output;
    output.position.xy = (t * float3(offsets[vid], 1.0)).xy;
    output.position.zw = float2(0, 1);
    output.arrow = arrow;
    
    return output;
}

fragment float4
arrows_fragment(
                ArrowVertexOutput vin [[ stage_in ]],
                constant const float4& color [[ buffer(0) ]]
                )
{
    return color;
}
