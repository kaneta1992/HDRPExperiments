#define PI 3.141592
#define PI2 (PI*2.0)

struct DistanceFunctionSurfaceData {
    float3 Position;
    float3 Normal;
    float3 BentNormal;

    float3 Albedo;
    float3 Emissive;
    float  Occlusion;
    float  Metallic;
    float  Smoothness;
};

DistanceFunctionSurfaceData initDistanceFunctionSurfaceData() {
    DistanceFunctionSurfaceData surface = (DistanceFunctionSurfaceData)0;
    surface.Albedo     = float3(1.0, 1.0, 1.0);
    surface.Occlusion  = 1.0;
    surface.Smoothness = 0.8;
    return surface;
}

float2x2 rot(in float a) {
    float s = sin(a), c = cos(a);
    return float2x2(c, s, -s, c);
}

float2 pmod(in float2 p, in float s) {
    float a = PI / s - atan2(p.x, p.y);
    float n = PI2 / s;
    a = floor(a / n) * n;
    return mul(rot(a), p);
}

float distanceFunction(float3 p);
DistanceFunctionSurfaceData getDistanceFunctionSurfaceData(float3 p);
void GetBuiltinData(FragInputs input, float3 V, inout PositionInputs posInput, SurfaceData surfaceData, float alpha, float3 bentNormalWS, float depthOffset, out BuiltinData builtinData);

float3 getObjectScale() {
    return float3(
        length(UNITY_MATRIX_M._11_21_31),
        length(UNITY_MATRIX_M._12_22_32),
        length(UNITY_MATRIX_M._13_23_33)
    );
}

float3x3 normalizedRotateMatrix() {
    float3x3 m;
    m._11_12_13 = normalize(UNITY_MATRIX_M._11_21_31);
    m._21_22_23 = normalize(UNITY_MATRIX_M._12_22_32);
    m._31_32_33 = normalize(UNITY_MATRIX_M._13_23_33);
    return m;
}

float map(float3 p) {
    float3 scale = getObjectScale();
    return distanceFunction(TransformWorldToObject(p)) * min(scale.x, min(scale.y, scale.z));
}

float map2(float3 p) {
    return distanceFunction(p);
}

float3 normal(float3 p, float eps) {
    p = TransformWorldToObject(p);
    float2 e = float2(1.0, -1.0) * eps;
    return TransformObjectToWorldDir(normalize(
        e.xyy * map2(p + e.xyy) +
        e.yxy * map2(p + e.yxy) +
        e.yyx * map2(p + e.yyx) +
        e.xxx * map2(p + e.xxx)
    ));
}

float ao(float3 p, float3 n, float dist) {
    float occ = 0.0;
    for (int i = 0; i < 16; ++i) {
        float h = 0.001 + dist*pow(float(i)/15.0,2.0);
        float oc = clamp(map( p + h*n )/h, -1.0, 1.0);
        occ += oc;
    }
    return occ / 16.0;
}

bool clipSphere(float3 p, float offset) {
    float d = length(TransformWorldToObject(p)) - (0.5 + offset);
    if (d < 0.0) {
        return false;
    } else {
        return true;
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
float3 GetRayOrigin(float3 positionRWS) {
    float3 pos = float3(0.0, 0.0, 0.0);
    if (clipSphere(float3(0.0, 0.0, 0.0), _ProjectionParams.y) > 0.0) {
        //pos = positionRWS;
    }
    return pos;
}

float3 GetShadowRayOrigin(float3 positionRWS)
{
    float3 viewPos = GetCurrentViewPosition();
    float3 pos = float3(0.0, 0.0, 0.0);

    if (IsPerspectiveProjection())
    {
        // Perspective(Point or Spot Light?)
        pos = viewPos;
    }
    else
    {
        // Orthographic(Directional Light?)
        pos = positionRWS;  // fix me?
    }

    // シャドウはNearの情報をシェーダーに渡していないので固定値にする
    float near = 0.1;
    if (clipSphere(viewPos, near) > 0.0) {
        //pos = positionRWS;
    }

    return pos;
}

float TraceDepth(float3 ro, float3 ray) {
    float t = 0.0001;
    float3 p;
    for(int i = 0; i< 64; i++) {
        p = ro + ray * t;
        float d = map(p);
        if (d < 0.00001) break;
        t += d;
    }
    if (clipSphere(p, 0.0)) {
        discard;
    }
    return t;
}

DistanceFunctionSurfaceData Trace(float3 ro, float3 ray) {
    float t = TraceDepth(ro, ray);
    return getDistanceFunctionSurfaceData(ray * t + ro);
}

void ToHDRPSurfaceAndBuiltinData(FragInputs input, float3 V, inout PositionInputs posInput, DistanceFunctionSurfaceData surface, out SurfaceData surfaceData, out BuiltinData builtinData) {
    surfaceData = (SurfaceData)0;
    surfaceData.materialFeatures = MATERIALFEATUREFLAGS_LIT_STANDARD;
    surfaceData.normalWS = surface.Normal;
    surfaceData.ambientOcclusion = surface.Occlusion;
    surfaceData.perceptualSmoothness = surface.Smoothness;
    surfaceData.specularOcclusion = GetSpecularOcclusionFromAmbientOcclusion(ClampNdotV(dot(surfaceData.normalWS, V)), surfaceData.ambientOcclusion, PerceptualSmoothnessToRoughness(surfaceData.perceptualSmoothness));
    surfaceData.baseColor = surface.Albedo;
    surfaceData.metallic = surface.Metallic;
    GetBuiltinData(input, V, posInput, surfaceData, 0.0, surface.BentNormal, 0.0, builtinData);
    builtinData.emissiveColor = surface.Emissive;
}

float WorldPosToDeviceDepth(float3 p) {
    float4 device = TransformWorldToHClip(p);
    return device.z / device.w;
}