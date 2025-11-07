
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

	float2 _MapSadowTintNoiseUVTiling;
	float _MapSadowTintStrength;
	float _MapSadowTintThresholdMin;
	float _MapSadowTintThresholdMax;

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
	float Alignment_1; // Alignment
};
