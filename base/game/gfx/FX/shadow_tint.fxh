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
	struct SShadowTintData
	{
		float2 _NoiseUV;
		float4 _TintColor;
		float _MapShadowTintStrengthValue;
	};

	SShadowTintData GetShadowTintData( float2 Coordinate )
	{
		SShadowTintData ShadowTintData;
		ShadowTintData._NoiseUV = Coordinate * _MapShadowTintNoiseUVTiling;
		ShadowTintData._TintColor = PdxTex2D( ShadowNoiseTexture, ShadowTintData._NoiseUV );
		ShadowTintData._MapShadowTintStrengthValue = _MapShadowTintStrength * ShadowTintData._TintColor.a;
		return ShadowTintData;
	}

	float3 GetShadowTintColorLowSpec()
	{
		return float3( 0.023f, 0.0230f, 0.033f ) * _MapShadowTintStrength;
	}

	float GetShadowTintMask( SShadowTintData ShadowTintData, float3 ToLightDir, float ShadowTerm, float3 TerrainNormal, float3 Normal )
	{
		float TerrainNdotL = saturate( dot( TerrainNormal, ToLightDir ) ) + 1e-5;
		float NdotL = saturate( dot( Normal, ToLightDir ) ) + 1e-5;

		float TerrainShadowTerm = smoothstep( _MapShadowTintThresholdMin, _MapShadowTintThresholdMax, TerrainNdotL );
		float ObjectShadowTerm = NdotL;
		float FinalShadowTerm = saturate( 3 - TerrainShadowTerm - ShadowTerm - ObjectShadowTerm);
		return ShadowTintData._MapShadowTintStrengthValue * FinalShadowTerm;
	}

	float GetTerrainShadowTintMask( SShadowTintData ShadowTintData, float3 ToLightDir, float ShadowTerm, float3 TerrainNormal )
	{
		float TerrainNdotL = saturate( dot( TerrainNormal, ToLightDir ) ) + 1e-5;
		float TerrainShadowTerm = smoothstep( _MapShadowTintThresholdMin, _MapShadowTintThresholdMax, TerrainNdotL );
		float FinalShadowTerm = saturate( 2 - TerrainShadowTerm - ShadowTerm );
		return ShadowTintData._MapShadowTintStrengthValue * FinalShadowTerm;
	}

	float3 ApplySunnyShadowTintWithClouds( float3 Color, float3 ShadowTintColor, float CloudMask, float ShadowTintMask, float SunnyMultiplier )
	{
		// Apply shadow tint
		float ShadowOutsideClouds = saturate( ShadowTintMask - CloudMask );
		Color = lerp( Color, ShadowTintColor, ShadowOutsideClouds * SunnyMultiplier );
		return Color;
	}

	// Apply shadow tint with cloud interaction - generic function
	float3 ApplyShadowTintWithClouds( float3 Color, float3 ShadowTintColor, float CloudMask, float ShadowTintMask, float SunnyMultiplier, float ShadowMultiplier )
	{
		// Apply shadow tint
		float ShadowOutsideClouds = saturate( ShadowTintMask - CloudMask );
		float ShadowInsideClouds = saturate( CloudMask - ( 1 - ShadowTintMask ) );

		Color = lerp( Color, ShadowTintColor, ShadowOutsideClouds * SunnyMultiplier );
		Color = lerp( Color, ShadowTintColor, ShadowInsideClouds * ShadowMultiplier );

		return Color;
	}

	// Apply shadow tint with cloud interaction - default multipliers
	float3 ApplyShadowTintWithClouds( float3 Color, float3 ShadowTintColor, float CloudMask, float ShadowTintMask )
	{
		return ApplyShadowTintWithClouds( Color, ShadowTintColor, CloudMask, ShadowTintMask, 1.0f, 0.8f );
	}
]]