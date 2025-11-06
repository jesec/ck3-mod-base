
# game constants
ConstantBuffer( GameSharedConstants )
{
	float2		MapSize;
	float 		GlobalTime;
	
	float		FlatMapHeight;
	float		FlatMapLerp;
	float		MapHighlightIntensity;
	float		SnowHighlightIntensity;

	int 		HasFlatMapLightingEnabled;
};
