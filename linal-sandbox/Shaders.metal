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

METAL_FUNC float3 hsv2rgb(float3 hsv) {
  constexpr float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  float3 p = abs(fract(hsv.xxx + K.xyz) * 6.0 - K.www);
  return hsv.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), hsv.y);
}

constant constexpr auto fieldLength = 4.0;

METAL_FUNC void drawGrid(thread float4* output, const float3 color, const float2 x, const float2 interval) {
    constexpr auto lt = 0.005 * fieldLength / 2.0;
    constexpr auto hlt = lt / 2;
    const auto boundary = 1.0 / interval;
    const auto xfract = fmod(abs(x), boundary);
    const auto vertical = all(xfract.x < hlt || xfract.x > boundary - hlt);
    const auto horizontal = all(xfract.y < hlt || xfract.y > boundary - hlt);
    if (vertical || horizontal) {
        output->rgb = color;
    }
}

METAL_FUNC float3x3 makeMatrix(thread const float2& x,
                               constant const float& time,
                               constant const float3x3& matrix)
{
    return matrix;
}

kernel void shader(texture2d<float, access::write> destination [[ texture(0) ]],
                   constant const float2& mousePosition [[ buffer(0) ]],
                   constant const float& time [[ buffer(1) ]],
                   constant const float4* circles [[ buffer(2) ]],
                   constant const int& circlesCount [[ buffer(3) ]],
                   constant const float3x3& uMatrix [[ buffer(4) ]],
                   uint2 pos [[ thread_position_in_grid ]]) {
    const float2 uv = float2(pos) / float2(destination.get_width(), destination.get_height());
    float2 x = uv2coord(uv) * fieldLength;
    const auto matrix = makeMatrix(x, time, uMatrix);
    x = (matrix * float3(x, 1.0)).xy;

//    const float2 ix = matrix[0].xy;
//    const float2 iy = matrix[1].xy;
//    float2 lxy = 1.0 / float2(length(ix), length(iy));
    float4 output = float4(0, 0, 0, 1.0);
    drawGrid(&output, float3(0.15), x, 2.0);
    drawGrid(&output, float3(0.5), x, 1.0);
    drawGrid(&output, float3(1.0), x, 0.0000001);
    
    for (int i = 0; i < circlesCount; i++) {
        const float2 center = (float3(circles[i].xy, 1.0)).xy;
        const float radius = circles[i].z;
        const float3 color = hsv2rgb(float3(circles[i].w, 1.0, 1.0));
        const float centerXDistance = length(center - x);
        if (centerXDistance <= radius) {
            output.rgb = color;
        }
    }
    
    destination.write(output, pos);
}
