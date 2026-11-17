# Flatmap lighting used while lerping between terrain and the flat map.
ConstantBuffer( FlatMapLerpEnvironment )
{
	float	FlatMapLerpCubemapIntensity;
	float3	FlatMapLerpSunDiffuse;
	float	FlatMapLerpSunIntensity;
	float4x4 FlatMapLerpCubemapYRotation;
};

PixelShader =
{
	TextureSampler FlatMapEnvironmentMap
	{
		Ref = FlatMapEnvironmentMap
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		Type = "Cube"
	}

	Code
	[[
		SLightingProperties GetFlatMapLerpSunLightingProperties( float3 WorldSpacePos, float ShadowTerm )
		{
			SLightingProperties LightingProps;
			LightingProps._ToCameraDir = normalize( CameraPosition - WorldSpacePos );
			LightingProps._ToLightDir = ToSunDir;
			LightingProps._LightIntensity = FlatMapLerpSunDiffuse * 5;
			LightingProps._ShadowTerm = ShadowTerm;
			LightingProps._CubemapIntensity = FlatMapLerpCubemapIntensity;
			LightingProps._CubemapYRotation = FlatMapLerpCubemapYRotation;

			return LightingProps;
		}

		void ApplyGoldenFlatMap( inout float3 Color, float FlatMapAlpha, float3 WorldSpacePos )
		{
			float GoldenMask = saturate( 1.0f - FlatMapAlpha );
			Color = lerp( 0.0f, Color, FlatMapAlpha );
			if ( GoldenMask > 0.001f )
			{
				SMaterialProperties GoldenMaterialProps;
				GoldenMaterialProps._PerceptualRoughness = 0.18f;
				GoldenMaterialProps._Roughness = RoughnessFromPerceptualRoughness( GoldenMaterialProps._PerceptualRoughness );
				GoldenMaterialProps._Metalness = 1.0f;
				GoldenMaterialProps._DiffuseColor = float3( 0.0f, 0.0f, 0.0f );
				GoldenMaterialProps._SpecularColor = float3( 1.0f, 0.78f, 0.22f );
				GoldenMaterialProps._Normal = float3( 0.0f, 1.0f, 0.0f );
				
				SLightingProperties GoldenLightingProps = GetFlatMapLerpSunLightingProperties( WorldSpacePos, 1.0f );
				GoldenLightingProps._ToLightDir = float3( -0.1f, 12.3f, 0.1f );
				GoldenLightingProps._LightIntensity = 0.0435f;
				float3 GoldenDiffuseLight;
				float3 GoldenSpecularLight;
				CalculateLightingFromLight( GoldenMaterialProps, GoldenLightingProps, GoldenDiffuseLight, GoldenSpecularLight );

				float3 GoldenDiffuseIBL;
				float3 GoldenSpecularIBL;
				CalculateLightingFromIBL( GoldenMaterialProps, GoldenLightingProps, FlatMapEnvironmentMap, GoldenDiffuseIBL, GoldenSpecularIBL );

				Color += ( GoldenSpecularLight + GoldenSpecularIBL ) * GoldenMask;
			}
		}
	]]
}
