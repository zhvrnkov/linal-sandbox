//
//  Circles.metal
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 1/16/23.
//

#include <metal_stdlib>
#include "../Common.metal"
using namespace metal;

kernel void circles(texture2d<float, access::read_write> destination [[ texture(0) ]],
                    constant const float& time [[ buffer(0) ]],
                    constant const float3x3& uMatrix [[ buffer(1) ]],
                    constant const float4* circles [[ buffer(2) ]],
                    constant const int& circlesCount [[ buffer(3) ]],
                    uint2 pos [[ thread_position_in_grid ]]) {
    const auto x = makeX(pos, destination, time, uMatrix);
    float4 output = destination.read(pos);
    for (int i = 0; i < circlesCount; i++) {
        const float2 center = circles[i].xy;
        const float radius = circles[i].z;
//        const float3 color = hsv2rgb(float3(circles[i].w, 1.0, 1.0));
        float3 color;
        {
            const float level = center.y * M_PI_F / 2.0;
            color.r = sin(level);
            color.g = sin(level*2.);
            color.b = cos(level);
        }
        const float centerXDistance = length(center - x);
        if (centerXDistance <= radius) {
            output.rgb = color;
        }
    }
    destination.write(output, pos);
}
