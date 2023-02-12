//
//  Common.metal
//  linal-sandbox
//
//  Created by Zhavoronkov Vlad on 1/16/23.
//

#include <metal_stdlib>
#include "Misc.metal"
using namespace metal;

METAL_FUNC float3x3 makeMatrix(thread const float2& x,
                               constant const float& time,
                               constant const float3x3& matrix)
{
    return matrix;
}

template<typename T>
METAL_FUNC float2 makeXAndM(uint2 pos,
                            T texture,
                            constant const float& time,
                            constant const float3x3& uMatrix,
                            thread float3x3 *outMatrix
                            ) {
    const float2 uv = makeUV(pos, texture);
    float2 x = uv2coord(uv);
    const auto matrix = makeMatrix(x, time, uMatrix);
    if (outMatrix) {
        *outMatrix = matrix;
    }
    x = (matrix * float3(x, 1.0)).xy;
    return x;
}

template<typename T>
METAL_FUNC float2 makeX(uint2 pos,
                        T texture,
                        constant const float& time,
                        constant const float3x3& uMatrix
                        ) {
    return makeXAndM(pos, texture, time, uMatrix, nullptr);
}

METAL_FUNC
float2 makeXYVertex(float2 position,
                    float3x3 matrix,
                    float3x3 invMatrix)
{
    auto m = invMatrix;
#warning weak place
    m[2].xy = float2x2(m[0].xy, m[1].xy) * -matrix[2].xy;
    return (m * float3(position, 1.0)).xy;
}
