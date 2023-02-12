//
//  Plot.metal
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 1/16/23.
//

#include <metal_stdlib>
#include "../Common.metal"
using namespace metal;

//#define f(x) cos(time + x)

constant constexpr float dx = 0.00001;
//float calcDeriv(float x, float(*f)(const float)) {
//    const auto dy = f(x + dx) - f(x);
//    return dy / dx;
//}

using F = float(float x, float time);
kernel void graph(
                  texture2d<float, access::read_write> destination [[ texture(0) ]],
                  constant const float& time [[ buffer(0) ]],
                  constant const float3x3& uMatrix [[ buffer(1) ]],
                  visible_function_table<F> table [[ buffer(2) ]],
                  constant const float4& color [[ buffer(3) ]],
                  uint2 pos [[ thread_position_in_grid ]]
                  )
{
    const auto x = makeX(pos, destination, time, uMatrix);
    
    float4 output = destination.read(pos);
    
    const auto f = table[0];
    const auto fx = f(x.x, time);
    const auto fdx = f(x.x + dx, time);
    const auto tx = float2(fx, pow(x.y, 1.0));
    const auto deriv = (fdx - fx) / dx;
    
    float t = abs(tx.y - tx.x);
    const auto plt = smoothstep(0.02 + abs(deriv) * 0.02, 0.0, t);
    
    output = mix(output, color, plt);
    
    destination.write(output, pos);
}
