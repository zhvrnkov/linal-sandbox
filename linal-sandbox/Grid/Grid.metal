//
//  Grid.metal
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 1/16/23.
//

#include <metal_stdlib>
#include "../Common.metal"
using namespace metal;

METAL_FUNC float maxSpaceScaleFactor(float3x3 space) {
    return max(length(space[0]), length(space[1]));
}

METAL_FUNC void drawGrid(
                         thread float4* output,
                         const float3 color,
                         const float2 x,
                         const float2 interval,
                         const float ltFactor
                         )
{
    auto lt = 0.005 * ltFactor / 2.0;
    auto hlt = lt / 2;
    const auto boundary = 1.0 / interval;
    const auto xfract = fmod(abs(x), boundary);
    const auto vertical = all(xfract.x < hlt || xfract.x > boundary - hlt);
    const auto horizontal = all(xfract.y < hlt || xfract.y > boundary - hlt);
    if (vertical || horizontal) {
        output->rgb = color;
    }
}

kernel void grid(texture2d<float, access::write> destination [[ texture(0) ]],
                 constant const float& time [[ buffer(0) ]],
                 constant const float3x3& uMatrix [[ buffer(1) ]],
                 uint2 pos [[ thread_position_in_grid ]]) {
    float3x3 matrix;
    const float2 x = makeXAndM(pos, destination, time, uMatrix, &matrix);
    const float ltFactor = maxSpaceScaleFactor(matrix);

    float4 output = float4(0, 0, 0, 1.0);
    drawGrid(&output, float3(0.15), x, 2.0, ltFactor);
    drawGrid(&output, float3(0.5), x, 1.0, ltFactor);
    drawGrid(&output, float3(1.0), x, 0.0000001, ltFactor);
    
    destination.write(output, pos);
}
