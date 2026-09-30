
# game constants
ConstantBuffer( GameSharedConstants )
{
	float2		MapSize;
	float 		GlobalTime;

	float		FlatMapHeight;
	float		FlatMapLerp;
	float		MapHighlightIntensity;
	float		SnowHighlightIntensity;
	float		FlatMapBrightnessIntensity;

	float2 _MapShadowTintNoiseUVTiling;
	float _MapShadowTintStrength;
	float _MapShadowTintThresholdMin;
	float _MapShadowTintThresholdMax;

	// Winter
	float _SnowValue;
	float _SnowExtent;
	float _SnowAngleRemove;
	int _SnowRandomNumber;

	int _SnowTexIndex;
	int _SnowNoiseTiling;
	int _SnowNoise2Tiling;
	int _SnowTextureTiling;

	float _FrostHemispherePosition;
	float _FrostHemisphereContrast;
	float _FrostTerrainAreaPosition;
	float _FrostTerrainAreaContrast;
	float _FrostMultiplier;

	float _SnowHemispherePosition;
	float _SnowHemisphereContrast;
	float _SnowTerrainAreaPosition;
	float _SnowTerrainAreaContrast;
	float _SnowAreaPosition;
	float _SnowAreaContrast;

	float _SnowGameMaskImpact;
	float _SnowGameMaskMin;
	float _SnowGameMaskMax;

	float _SnowHeightWeight;
	float _SnowHeightContrast;

	float _SnowTerrainHeightAdd;
	float _SnowTerrainHeightMin;
	float _SnowTerrainHeightMax;

	float _DebugSeasonWinter;

	int _HasCloudShadowEnabled;
	int _HasTreeDitheringEnabled;

	float _EnabledTerrainCulling;
	float _StartColorOverlayHeightBlend;
	float _FullyColorOverlayHeightBlend;
	float _RefractionCullHeight;
	float _Alignment1;

	float3 _UnderwaterTerrainColor;

	float _RiteDivergenceHostilityThreshold;
	float _RiteDivergenceHereticalThreshold;

	float _Alignment2; // Alignment
	float _Alignment3; // Alignment
	float _Alignment4; // Alignment
};
