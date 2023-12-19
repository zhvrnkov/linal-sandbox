//
//  FieldKernel.metal
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 2/1/23.
//

#include <metal_stdlib>
using namespace metal;

float2 E(float2 pos, float2 mpos, float m)
{
    constexpr float G = 6.67;
    const float2 radiusVector = pos - mpos;
    const float radius = length(radiusVector);
    
    return -G * m / pow(radius, 3.0) * radiusVector;
}

float2 field(const float2 position, const float time)
{
    constexpr const float mu = 0.1;
    constexpr const float g = 9.8;
    constexpr const float L = 2.0;

    const float theta = position.x;
    const float thetaDot = position.y;
    const float thetaDotDot = -mu * thetaDot - (g / L) * sin(theta);

    const float2 vector = float2(thetaDot, thetaDotDot);
    return normalize(vector) * 0.25;
//    return 0.35 * float2(sin(position.y + time), sin(position.x + time));
//
//    float m1 = 0.1 * cos(0.5 * time);
//    float m2 = 0.1 * -cos(0.5 * time);
//    const float2 mpos1 = float2(-2, 0);
//    const float2 mpos2 = float2(2, 0);
//    
//    const auto E1 = E(position, mpos1, m1);
//    const auto E2 = E(position, mpos2, m2);
//    
//    return E1 + E2;
}

kernel void field_kernel(
                         constant const float2* points [[ buffer(0) ]],
                         device float4* result [[ buffer(1) ]],
                         constant const float& time [[ buffer(2) ]],
                         uint index [[ thread_position_in_grid ]]
                         )
{
    const float2 position = points[index];
    float2 fieldValue = field(position, time);
    if (length(fieldValue) > 1.0)
        fieldValue = float2(0);
    
    result[index] = float4(position, position + fieldValue);
}
