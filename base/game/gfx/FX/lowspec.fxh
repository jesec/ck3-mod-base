Includes = {
	"jomini/jomini_lighting.fxh"
	"jomini/map_lighting.fxh"
	"shadow_tint.fxh"
}

PixelShader = {
	Code
	[[

		void CalculateLightingFromLightLowSpec( SMaterialProperties MaterialProps, float3 ToCameraDir, float3 ToLightDir, float3 LightIntensity, out float3 DiffuseOut, out float3 SpecularOut )
		{
			float3 H = normalize( ToCameraDir + ToLightDir );
			float NdotV = saturate( dot( MaterialProps._Normal, ToCameraDir ) ) + 1e-5;
			float NdotL = saturate( dot( MaterialProps._Normal, ToLightDir ) ) + 1e-5;
			float NdotH = saturate( dot( MaterialProps._Normal, H ) );
			float LdotH = saturate( dot( ToLightDir, H ) );

			#ifdef PDX_DECREASE_SPECULAR_LIGHT
				LdotH = lerp( 0.5f, 1.0f, LdotH );
				NdotL = lerp( 0.0f, 0.7f, NdotL );
			#endif 

			float DiffuseBRDF = CalcDiffuseBRDF( NdotV, NdotL, LdotH, MaterialProps._PerceptualRoughness );
			DiffuseOut = DiffuseBRDF * MaterialProps._DiffuseColor * LightIntensity * NdotL;

			float3 DarkTintColor = GetShadowTintColorLowSpec();
			DiffuseOut = lerp( DarkTintColor, DiffuseOut, smoothstep ( 0.0f , 1.0f,  NdotL * LightIntensity ) );

		#ifdef PDX_HACK_ToSpecularLightDir
			float3 H_Spec = normalize( ToCameraDir + PDX_HACK_ToSpecularLightDir );
			float NdotL_Spec = saturate( dot( MaterialProps._Normal, PDX_HACK_ToSpecularLightDir ) ) + 1e-5;
			float NdotH_Spec = saturate( dot( MaterialProps._Normal, H_Spec ) );
			float LdotH_Spec = saturate( dot( PDX_HACK_ToSpecularLightDir, H_Spec ) );
			float3 SpecularBRDF = CalcSpecularBRDF( MaterialProps._SpecularColor, LdotH_Spec, NdotH_Spec, NdotL_Spec, NdotV, MaterialProps._Roughness );
			SpecularOut = SpecularBRDF * LightIntensity * NdotL;
		#else
			float3 SpecularBRDF = CalcSpecularBRDF( MaterialProps._SpecularColor, LdotH, NdotH, NdotL, NdotV, MaterialProps._Roughness );
			SpecularOut = SpecularBRDF * LightIntensity * NdotL;
		#endif
		}
		void CalculateLightingFromLightLowSpec( SMaterialProperties MaterialProps, SLightingProperties LightingProps, out float3 DiffuseOut, out float3 SpecularOut )
		{
			CalculateLightingFromLightLowSpec( MaterialProps, LightingProps._ToCameraDir, LightingProps._ToLightDir, LightingProps._LightIntensity * LightingProps._ShadowTerm, DiffuseOut, SpecularOut );
		}

		float3 CalculateTerrainSunLightingLowSpec( SMaterialProperties MaterialProps, SLightingProperties LightingProps )
		{
			#ifndef TERRAIN_FLAT_MAP_LERP
				LightingProps._ToLightDir = ToTerrainSunnySunDir;
				LightingProps._LightIntensity = TERRAIN_SUNNY_SUN_COLOR * TERRAIN_SUNNY_SUN_INTENSITY;
			#endif

			float3 DiffuseLight;
			float3 SpecularLight;
			CalculateLightingFromLightLowSpec( MaterialProps, LightingProps, DiffuseLight, SpecularLight );

			const float MinDiffuse = MaterialProps._DiffuseColor.r * 0.1f;
			DiffuseLight = lerp( MinDiffuse, 1.0f, DiffuseLight );
			return DiffuseLight + SpecularLight;
		}

		float3 CalculateMapObjectsSunLightingLowSpec( SMaterialProperties MaterialProps, SLightingProperties LightingProps )
		{
			#ifndef TERRAIN_FLAT_MAP_LERP
				LightingProps._ToLightDir = ToMapObjectsSunnySunDir;
				LightingProps._LightIntensity = MAP_OBJECTS_SUNNY_SUN_COLOR * MAP_OBJECTS_SUNNY_SUN_INTENSITY;
			#endif

			float3 DiffuseLight;
			float3 SpecularLight;
			CalculateLightingFromLightLowSpec( MaterialProps, LightingProps, DiffuseLight, SpecularLight );

			const float MinDiffuse =  MaterialProps._DiffuseColor.r * 0.3f;
			DiffuseLight = lerp( MinDiffuse, 1.0f, DiffuseLight );
			return DiffuseLight + SpecularLight;
		}

		float3 CalculateSunLightingLowSpec( SMaterialProperties MaterialProps, SLightingProperties LightingProps )
		{
			float3 DiffuseLight;
			float3 SpecularLight;
			CalculateLightingFromLight( MaterialProps, LightingProps, DiffuseLight, SpecularLight );
			
			const float minDiffuse = 0.007;
			
			DiffuseLight = float3(minDiffuse, minDiffuse, minDiffuse) + (1.0 - minDiffuse) * DiffuseLight;
			return DiffuseLight + SpecularLight;
		}
	]]
}
