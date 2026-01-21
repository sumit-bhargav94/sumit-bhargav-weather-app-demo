//
//  LiquidGlass.metal
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

//#include <metal_stdlib>
//using namespace metal;
//
//
//[[ stitchable ]]
//half2 liquidRefraction(
//    float2 position,
//    float time,
//    float intensity
//) {
//    float wave =
//        sin(position.y * 0.04 + time * 1.5) * 6.0 +
//        cos(position.x * 0.03 + time * 1.2) * 4.0;
//
//    return half2(wave * intensity, wave * intensity * 0.6);
//}

#include <metal_stdlib>
using namespace metal;

[[ stitchable ]]
float2 liquidRefraction(
    float2 position,
    float time,
    float intensity
) {
    float wave =
        sin(position.y * 0.04 + time * 1.2) * 4.0 +
        cos(position.x * 0.03 + time * 1.0) * 3.0;

    return float2(
        wave * intensity,
        wave * intensity * 0.6
    );
}
