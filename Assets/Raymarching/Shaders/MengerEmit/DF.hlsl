float dMenger(float3 z0, float3 offset, float scale) {
    float4 z = float4(z0, 1.0);
    for (int n = 0; n < 2; n++) {
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
    float scale = 4.0;
    p *= scale;
    p.yx = pmod(p.yx, 4.0);
    return dMenger(p, float3(1.0, 1.0, 1.0), 3.0) / scale;
}

DistanceFunctionSurfaceData getDistanceFunctionSurfaceData(float3 p) {
    DistanceFunctionSurfaceData surface = initDistanceFunctionSurfaceData();
    surface.Position = p;
    surface.Normal   = normal(p, 0.0001);
    surface.Occlusion = ao(p, surface.Normal, 1.0);
    surface.BentNormal = surface.Normal * surface.Occlusion; // nonsense
    surface.Albedo = float3(1.0, 1.0, 1.0);
    surface.Smoothness = 0.8;
    surface.Metallic = 0.0;
    
    float edge = saturate( pow( length( surface.Normal - normal( surface.Position, 0.002 ) ) * 2.0, 2.0 ) );
    surface.Emissive = float3(10000.0, 1000., 100.) * 4.0 * edge;
    return surface;
}