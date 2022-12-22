//
//  Shaders.metal
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 12/22/22.
//

#include <metal_stdlib>
using namespace metal;

METAL_FUNC bool fInRange(float f, float min, float max) {
    return f > min && f < max;
}

METAL_FUNC float2 uv2coord(float2 uv) {
    return fma(uv, 2, -1) * float2(1.0, -1.0);
}

METAL_FUNC float2 coord2uv(float2 coord) {
    return fma(coord * float2(1.0, -1.0), 0.5, 0.5);
}

METAL_FUNC void drawGrid(thread float4* output, const float3 color, const float2 x, const float interval) {
    constexpr auto lt = 0.005;
    constexpr auto hlt = lt / 2;
    const auto boundary = 1.0 / interval;
    const auto xfract = fmod(abs(x), boundary);
    const auto vertical = xfract.x < hlt || xfract.x > boundary - hlt;
    const auto horizontal = xfract.y < hlt || xfract.y > boundary - hlt;
    if (vertical || horizontal) {
        output->rgb = color;
    }
}

kernel void shader(texture2d<float, access::write> destination [[ texture(0) ]],
                   constant const float2& mousePosition [[ buffer(0) ]],
                   constant const float& time [[ buffer(1) ]],
                   uint2 pos [[ thread_position_in_grid ]]) {
    constexpr auto fieldLength = 2.0;
    const float2 uv = float2(pos) / float2(destination.get_width(), destination.get_height());
    const float2 x = uv2coord(uv) * fieldLength;

    float4 output = float4(0, 0, 0, 1.0);
    drawGrid(&output, float3(0.15), x, 2.0);
    drawGrid(&output, float3(0.5), x, 1.0);
    drawGrid(&output, float3(1.0), x, 0.0000001);
    destination.write(output, pos);
}
