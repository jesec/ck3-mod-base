Includes = {
	"cw/camera.fxh"
	"cw/random.fxh"
	"cw/pdxterrain.fxh"
	"jomini/jomini.fxh"
	"jomini/jomini_fog_of_war.fxh"
}


Code
[[
	float CalculateZoomFogFactor()
	{
		// Fog stays full until zoom 0.24, then fades out
		float ZoomedInZoomedOutFactor = GetZoomedInZoomedOutFactor();
		return min( 1.0f, pow( 1.0f - ZoomedInZoomedOutFactor + 0.15f, 6.0f ) );
	}

	float CalculateDistanceFogFactor( float3 WorldSpacePos )
	{
		float3 Diff = CameraPosition - WorldSpacePos;
		float vFogFactor = 1.0 - abs( normalize( Diff ).y );
		float vSqDistance = dot( Diff, Diff );

		float vMin = min( ( vSqDistance - FogBegin2 ) / ( FogEnd2 - FogBegin2 ), FogMax );
		return saturate( vMin * vFogFactor );
	}

	float CalculateMapDistanceFogFactor( float3 WorldSpacePos, 
		PdxTextureSampler2D FogOfWarAlphaSampler )
	{
		
		// Get fog of war alpha value
		float FogOfWarAlphaValue = PdxTex2D( FogOfWarAlphaSampler, 
			WorldSpacePos.xz * WorldSpaceToTerrain0To1 ).r;
		
		// Skip fog calculations if in fog of war
		// if ( FogOfWarAlphaValue < 0.1f )
		// 	return 0.0f;

		float3 Diff = CameraPosition - WorldSpacePos;
		float vFogFactor = 1.0 - abs( normalize( Diff ).y );
		float vSqDistance = dot( Diff, Diff );

		float vMin = min( ( vSqDistance - FogBegin2 ) / ( FogEnd2 - FogBegin2 ), FogMax );
		float baseFogFactor = saturate( vMin * vFogFactor );
		float fogScale       = 0.3f + 0.7f * FogOfWarAlphaValue;
		return baseFogFactor * fogScale;
	}

	float3 ApplyDistanceFog( float3 Color, float vFogFactor )
	{
		return lerp( Color, FogColor, vFogFactor );
	}

	float3 ApplyDistanceFog( float3 Color, float3 WorldSpacePos )
	{
		float vFogFactor = CalculateDistanceFogFactor( WorldSpacePos );

		// Calculate a blend factor based on the position relative to the camera
		float BlendFactor = smoothstep( CameraPosition.x + RelativeFogBegin, CameraPosition.x - RelativeFogEnd, WorldSpacePos.x );

		// Interpolate between the original fog color and the relative fog color
		float3 BlendedFogColor = FogColor + BlendFactor * RelativeFogColor;

		// Ensure the resulting color channels do not exceed 1
		BlendedFogColor = min( BlendedFogColor, float3( 1.0f, 1.0f, 1.0f ) );

		// Calculate a height factor to reduce fog effect higher up
		float HeightFactor = smoothstep( RelativeFogHeightBegin, RelativeFogHeightEnd, WorldSpacePos.y );
		float NoiseValue = CalcNoise( WorldSpacePos.xz * 0.02f );

		vFogFactor *= ( 1.0f + 0.5f * ( NoiseValue ) );

		vFogFactor *= ( 1.0f - HeightFactor );


		return lerp( Color, BlendedFogColor, vFogFactor );
	}

	float3 CalculateFogColor( float3 Color, float3 WorldSpacePos, float FogFactor )
	{
		// Calculate a blend factor based on the position relative to the camera
		float BlendFactor = smoothstep( CameraPosition.x + RelativeFogBegin, CameraPosition.x - RelativeFogEnd, WorldSpacePos.x );

		// Interpolate between the original fog color and the relative fog color
		float3 BlendedFogColor = FogColor + BlendFactor * RelativeFogColor;

		// Ensure the resulting color channels do not exceed 1
		BlendedFogColor = min( BlendedFogColor, vec3( 1.0f ) );

		// Calculate a height factor to reduce fog effect higher up
		float HeightFactor = smoothstep( RelativeFogHeightBegin, RelativeFogHeightEnd, WorldSpacePos.y );
		float NoiseValue = CalcNoise( WorldSpacePos.xz * 0.02f );

		FogFactor *= ( 1.0f + 0.5f * ( NoiseValue ) );
		FogFactor *= ( 1.0f - HeightFactor );

		return lerp( Color, BlendedFogColor, FogFactor);
	}

	float3 ApplyMapDistanceFogWithoutFoW( float3 Color, float3 WorldSpacePos )
	{
		float FogFactor = CalculateDistanceFogFactor( WorldSpacePos );
		float ZoomFadeFactor = CalculateZoomFogFactor();
		return CalculateFogColor( Color, WorldSpacePos, FogFactor * ZoomFadeFactor );
	}

	float3 ApplyMapDistanceFog( float3 Color, float3 WorldSpacePos, 
		PdxTextureSampler2D FogOfWarAlphaSampler )
	{
		float FogFactor = CalculateMapDistanceFogFactor( WorldSpacePos, FogOfWarAlphaSampler );
		float ZoomFadeFactor = CalculateZoomFogFactor();
		return CalculateFogColor( Color, WorldSpacePos, FogFactor * ZoomFadeFactor );
	}
]]
