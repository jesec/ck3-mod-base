Includes = {
	"jomini/jomini_lighting.fxh"
}

PixelShader = {
	Code
	[[
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
