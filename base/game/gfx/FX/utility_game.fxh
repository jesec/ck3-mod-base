
Code
[[
	#define NotileNoiseTiling 0.2
	#define NotileNoiseStrength 10.0
	#define NotileVariation 5.0

	// Reduce tiling as explained by this article: https://iquilezles.org/articles/texturerepetition/, Technique 3
	float4 SampleNoTile( PdxTextureSampler2D Texture, float2 UV )
	{
		float RegionLookUp = CalcNoise( UV * NotileNoiseTiling ) * NotileNoiseStrength;	// Offset noise
		float FractionalRegionLookUp = frac( RegionLookUp );

		float2 DxUV = ddx( UV );
		float2 DyUV = ddy( UV );

		float2 HashA = sin( float2( 11.0, 5.0 ) * floor( RegionLookUp + 0.5 ) );
		float2 HashB = sin( float2( 11.0, 5.0 ) * floor( RegionLookUp ) );

		float4 SampleA = PdxTex2DGrad( Texture, UV + ( NotileVariation * HashA ), DxUV, DyUV );
		float4 SampleB = PdxTex2DGrad( Texture, UV + ( NotileVariation * HashB ), DxUV, DyUV );

		float DistanceToTexture = ( min( FractionalRegionLookUp, 1.0 - FractionalRegionLookUp ) * 2.0 ) - ( 0.1 * dot( SampleA.rgb - SampleB.rgb, float3( 1.0, 1.0, 1.0 ) ) );

		return lerp ( SampleA, SampleB, smoothstep( 0.2, 0.8, DistanceToTexture ) );
	}

	float4 SampleNoTile( PdxTextureSampler2DArray Texture, float2 UV, float Index )
	{
		float RegionLookUp = CalcNoise( UV * NotileNoiseTiling ) * NotileNoiseStrength;	// Offset noise
		float FractionalRegionLookUp = frac( RegionLookUp );

		float2 DxUV = ddx( UV );
		float2 DyUV = ddy( UV );

		float2 HashA = sin( float2( 11.0, 5.0 ) * floor( RegionLookUp + 0.5 ) );
		float2 HashB = sin( float2( 11.0, 5.0 ) * floor( RegionLookUp ) );

		float4 SampleA = PdxTex2DGrad( Texture, float3( UV + ( NotileVariation * HashA ), Index ), DxUV, DyUV );
		float4 SampleB = PdxTex2DGrad( Texture, float3( UV + ( NotileVariation * HashB ), Index ), DxUV, DyUV );

		float DistanceToTexture = ( min( FractionalRegionLookUp, 1.0 - FractionalRegionLookUp ) * 2.0 ) - ( 0.1 * dot( SampleA.rgb - SampleB.rgb, float3( 1.0, 1.0, 1.0 ) ) );

		return lerp ( SampleA, SampleB, smoothstep( 0.2, 0.8, DistanceToTexture ) );
	}

	// S-curve brightness adjustment function for FlatMap
	// Brightens midtones while preserving shadows and highlights
	float3 ApplyFlatMapBrightnessAdjustment( float3 Color )
	{
		// S-curve adjustment parameters
		float contrast = 1.35f;  // Curve steepness ( 1.0f - 2.0f )
		float brightness = 0.16f; // Overall brightness ( -0.2f to 0.3f )
		// Apply S-curve transformation
		Color = Color - 0.5f;
		Color = Color * contrast;
		Color = Color + 0.5f + brightness;
		Color = saturate( Color ); // Clamp to 0-1 range

		// Apply subtle gamma for fine-tuning
		float gamma = lerp( 1.15f, 0.75f, FlatMapBrightnessIntensity ); // Slight brightening, default value is 0.95f
		Color *= lerp( 0.5f, 1.5f, FlatMapBrightnessIntensity );

		Color = pow( Color, gamma );
		Color = saturate(Color);
		return Color;
	}
]]