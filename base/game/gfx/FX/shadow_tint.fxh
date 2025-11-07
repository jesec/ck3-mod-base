Includes = {
	"standardfuncsgfx.fxh"
	"cw/heightmap.fxh"
}

TextureSampler ShadowNoiseTexture
{
	Index = 12
	MagFilter = "Linear"
	MinFilter = "Linear"
	MipFilter = "Linear" 
	SampleModeU = "Wrap"
	SampleModeV = "Wrap"
	File = "gfx/map/textures/shadow_color.dds"
	sRGB = yes
}

Code
[[
	float GetShadowTintMask( float2 NoiseUV, float3 ToLightDir, float ShadowTerm, float3 TerrainNormal, float3 Normal )
	{
		float TerrainNdotL = saturate( dot( TerrainNormal, ToLightDir ) ) + 1e-5;
		float NdotL = saturate( dot( Normal, ToLightDir ) ) + 1e-5;

		float TerrainShadowTerm = smoothstep( _MapSadowTintThresholdMin, _MapSadowTintThresholdMax, TerrainNdotL );
		float ObjectShadowTerm = NdotL;
		float FinalShadowTerm = saturate( 3 - TerrainShadowTerm - ShadowTerm - ObjectShadowTerm);

		NoiseUV *= _MapSadowTintNoiseUVTiling;
		float4 NoiseColor = PdxTex2D( ShadowNoiseTexture, NoiseUV );
		
		return _MapSadowTintStrength * FinalShadowTerm * NoiseColor.a;
	}

	float GetTerrainShadowTintMask( float2 NoiseUV, float3 ToLightDir, float ShadowTerm, float3 TerrainNormal )
	{
		float TerrainNdotL = saturate( dot( TerrainNormal, ToLightDir ) ) + 1e-5;
		float TerrainShadowTerm = smoothstep( _MapSadowTintThresholdMin, _MapSadowTintThresholdMax, TerrainNdotL );
		float FinalShadowTerm = saturate( 2 - TerrainShadowTerm - ShadowTerm );

		NoiseUV *= _MapSadowTintNoiseUVTiling;
		float4 NoiseColor = PdxTex2D( ShadowNoiseTexture, NoiseUV );
		
		return _MapSadowTintStrength * FinalShadowTerm * NoiseColor.a;
	}

	float3 GetShadowTintColor( float2 NoiseUV )
	{
		NoiseUV *= _MapSadowTintNoiseUVTiling;
		return PdxTex2D( ShadowNoiseTexture, NoiseUV ).rgb;
	}

	// Apply shadow tint with cloud interaction - generic function
	float3 ApplyShadowTintWithClouds( float3 Color, float2 WorldPosition, float CloudMask, float ShadowTintMask, float SunnyMultiplier, float ShadowMultiplier )
	{
		// Apply shadow tint
		float3 ShadowTintColor = GetShadowTintColor( WorldPosition );
		float ShadowOutsideClouds = saturate( ShadowTintMask - CloudMask );
		float ShadowInsideClouds = saturate( CloudMask - ( 1 - ShadowTintMask ) );

		Color = lerp( Color, ShadowTintColor, ShadowOutsideClouds * SunnyMultiplier );
		Color = lerp( Color, ShadowTintColor, ShadowInsideClouds * ShadowMultiplier );

		return Color;
	}

	// Apply shadow tint with cloud interaction - default multipliers
	float3 ApplyShadowTintWithClouds( float3 Color, float2 WorldPosition, float CloudMask, float ShadowTintMask )
	{
		return ApplyShadowTintWithClouds( Color, WorldPosition, CloudMask, ShadowTintMask, 1.0f, 0.8f );
	}
]]