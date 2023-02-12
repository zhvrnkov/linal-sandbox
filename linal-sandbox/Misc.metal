//
//  Common.metal
//  sdf-example
//
//  Created by Zhavoronkov Vlad on 1/9/23.
//

#include <metal_stdlib>
using namespace metal;

METAL_FUNC float3x3 float3x3_z_rotataion(float angle) {
    float3x3 output = float3x3(1.0);
    float c;
    float s = sincos(angle, c);
    output[0] = float3(c, s, 0);
    output[1] = float3(-s, c, 0);
    return output;
}

METAL_FUNC float3x3 float3x3_x_rotataion(float angle) {
    float3x3 output = float3x3(1.0);
    float c;
    float s = sincos(angle, c);
    output[1] = float3(0, c, s);
    output[2] = float3(0, -s, c); // angle + pi/2
    return output;
}

METAL_FUNC float3x3 float3x3_y_rotataion(float angle) {
    float3x3 output = float3x3(1.0);
    float c;
    float s = sincos(angle, c);
    output[0] = float3(c, 0, -s); // angle - pi/2
    output[2] = float3(s, 0, c);
    return output;
}

METAL_FUNC float3x3 float3x3_rotataion(float3 angles) {
    const auto xRot = float3x3_x_rotataion(angles.x);
    const auto yRot = float3x3_y_rotataion(angles.y);
    const auto zRot = float3x3_z_rotataion(angles.z);
    
    return zRot * yRot * xRot;
}

template <typename T>
float2 texture2d_size(T texture) {
    return float2(float(texture.get_width()), float(texture.get_height()));
}

template<typename T>
METAL_FUNC float2 makeUV(uint2 pos, T texture) {
    return float2(pos) / float2(texture2d_size(texture));
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

METAL_FUNC bool fInRange(float f, float min, float max) {
    return f > min && f < max;
}
