float dMenger(float3 z0, float3 offset, float scale) {
    float4 z = float4(z0, 1.0);
    for (int n = 0; n < 4; n++) {
        z = abs(z);

        if (z.x < z.y) z.xy = z.yx;
        if (z.x < z.z) z.xz = z.zx;
        if (z.y < z.z) z.yz = z.zy;

        z *= scale;
        z.xyz -= offset * (scale - 1.0);

        if (z.z < -0.5 * offset.z * (scale - 1.0))
            z.z += offset.z * (scale - 1.0);
    }
    return (length(max(abs(z.xyz) - float3(1.0, 1.0, 1.0), 0.0)) - 0.05) / z.w;
}

float distanceFunction(float3 p) {
    float scale = 100.0;
    p *= float3(scale, scale*2.0, scale);
    float r = 2.75;
    p.xz = mod(p.xz - r*0.5, r) - r*0.5;
    float d = dMenger(p, float3(1.9 + sin(_Time.y*2.0 + p.x) * 0.02, 1.0+ sin(_Time.y*6.0 + p.z) * 0.01, 1.9 + sin(_Time.y*3.0 + p.z) * 0.02), 3.0) / (scale*2.0);
    //float d = dMenger(p, float3(2.0, 1.0, 2.0), 3.0) / (scale*2.0);
    //d = length(p) - 0.1;
    return d;
}

DistanceFunctionSurfaceData getDistanceFunctionSurfaceData(float3 p) {
    DistanceFunctionSurfaceData surface = initDistanceFunctionSurfaceData();
    surface.Position = p;
    surface.Normal   = normal(p, 0.000001);
    surface.Occlusion = ao(p, surface.Normal, 1.0);
    surface.BentNormal = surface.Normal * surface.Occlusion; // nonsense
    surface.Albedo = lerp(float3(1.0, 1.0, 1.0), float3(0.7, 0.1, 0.05), clamp((-p.y - _WorldSpaceCameraPos.y - 23) * 0.1, 0.0, 1.0));
    surface.Smoothness = lerp(0.4, 0.8, clamp((-p.y - _WorldSpaceCameraPos.y - 23) * 0.1, 0.0, 1.0));
    surface.Metallic = 0.0;
    //surface.Emissive = float3(10000.0, 1000., 100.) * 2.0;
    float edge = saturate( pow( length( surface.Normal - normal( surface.Position, 0.000008 ) ) * 2.0, 2.0 ) );
    surface.Emissive = float3(10000.0, 1000., 100.) * 4.0 * edge * clamp(sin(_Time.y), 0.0, 1.0) * clamp((-p.y - _WorldSpaceCameraPos.y - 30) * 0.1, 0.0, 1.0);

    return surface;
}