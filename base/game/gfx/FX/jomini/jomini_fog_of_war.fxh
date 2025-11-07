Includes = {
	#"cw/utility.fxh"
}

ConstantBuffer( JominiFogOfWar )
{
	float2	FogOfWarAlphaMapSize;
	float2	InverseWorldSize;
	float2	FogOfWarPatternSpeed;
	float	FogOfWarPatternStrength;
	float	FogOfWarPatternTiling;
	float	FogOfWarTime;
	float	FogOfWarAlphaMin;
	float	FogOfWarContrast;
	float	FogOfWarBrightness
}

PixelShader = 
{
	Code
	[[
		#ifndef FOG_OF_WAR_BLEND_FUNCTION
			#define FOG_OF_WAR_BLEND_FUNCTION loc_BlendFogOfWar
			float4 loc_BlendFogOfWar( float Alpha )
			{
				return float4( float3(0.0, 0.00, 0.00), 1.0 - Alpha );
			}
		#endif
		
		void loc_ApplyFogOfWarPattern( inout float Alpha, in float3 Coordinate, PdxTextureSampler2D FogOfWarAlphaMask )
		{
			if( FogOfWarPatternStrength > 0.0f )
			{
				float2 UV = Coordinate.xz * InverseWorldSize * FogOfWarPatternTiling;
				UV += FogOfWarPatternSpeed * 0.5 * FogOfWarTime;
				float Noise1 = 1.0f - PdxTex2D( FogOfWarAlphaMask, UV ).g;
				float Noise2 = 1.0f - PdxTex2D( FogOfWarAlphaMask, UV * -0.13 ).g;
				float Detail = 0.5f;
				
				float Noise = saturate( Noise2 * (1.0f-Detail) + Detail * 0.5f + (Noise1-0.5f) * Detail );
				
				Noise *= 1.0f - Alpha;
				Alpha = smoothstep( 0.0, 1.0, Alpha + Noise * FogOfWarPatternStrength );
			}
		}
		float GetFogOfWarAlpha( in float3 Coordinate, PdxTextureSampler2D FogOfWarAlphaMask )
		{		
			float Alpha = PdxTex2D( FogOfWarAlphaMask, Coordinate.xz * InverseWorldSize ).r;
			
			loc_ApplyFogOfWarPattern( Alpha, Coordinate, FogOfWarAlphaMask );
			
			return FogOfWarAlphaMin + Alpha * (1.0f - FogOfWarAlphaMin);
		}
		
		float GetFogOfWarAlphaWithTransitionRing( in float3 Coordinate, PdxTextureSampler2D FogOfWarAlphaMask, out float TransitionRing )
		{		
			float Alpha = PdxTex2D( FogOfWarAlphaMask, Coordinate.xz * InverseWorldSize ).r;
			
			// Sample neighboring positions to detect transition zones
			float SampleDistance = 4.0f;
			float2 UV = Coordinate.xz * InverseWorldSize;
			float AlphaUp = PdxTex2D( FogOfWarAlphaMask, UV + float2(0, SampleDistance) * InverseWorldSize ).r;
			float AlphaDown = PdxTex2D( FogOfWarAlphaMask, UV + float2(0, -SampleDistance) * InverseWorldSize ).r;
			float AlphaLeft = PdxTex2D( FogOfWarAlphaMask, UV + float2(-SampleDistance, 0) * InverseWorldSize ).r;
			float AlphaRight = PdxTex2D( FogOfWarAlphaMask, UV + float2(SampleDistance, 0) * InverseWorldSize ).r;
			
			// Calculate gradient magnitude
			float GradientX = abs(AlphaRight - AlphaLeft);
			float GradientY = abs(AlphaUp - AlphaDown);
			float GradientMagnitude = sqrt(GradientX * GradientX + GradientY * GradientY);
			
			// Create ring effect - strong gradient = transition zone
			TransitionRing = smoothstep(0.1, 0.4, GradientMagnitude);
			
			loc_ApplyFogOfWarPattern( Alpha, Coordinate, FogOfWarAlphaMask );
			
			return FogOfWarAlphaMin + Alpha * (1.0f - FogOfWarAlphaMin);
		}
		float GetFogOfWarAlphaMultiSampled( in float3 Coordinate, PdxTextureSampler2D FogOfWarAlphaMask )
		{
			float Width = 2.0f;
			float Alpha = 0.0f; 
			Alpha += PdxTex2D( FogOfWarAlphaMask, ( Coordinate.xz + float2( 0,-1) * Width ) * InverseWorldSize ).r;
			Alpha += PdxTex2D( FogOfWarAlphaMask, ( Coordinate.xz + float2(-1, 0) * Width ) * InverseWorldSize ).r;
			Alpha += PdxTex2D( FogOfWarAlphaMask, ( Coordinate.xz + float2( 1, 0) * Width ) * InverseWorldSize ).r;
			Alpha += PdxTex2D( FogOfWarAlphaMask, ( Coordinate.xz + float2( 0, 1) * Width ) * InverseWorldSize ).r;
			Alpha /= 4.0f;
			
			loc_ApplyFogOfWarPattern( Alpha, Coordinate, FogOfWarAlphaMask );
			
			return FogOfWarAlphaMin + Alpha * (1.0f - FogOfWarAlphaMin);
		}

		float3 FogOfWarColorAdjustment( in float3 Color, in float Alpha )
		{
			const float ContrastFactor = FogOfWarContrast + 1.0f;
			const float Average = dot( Color.rgb, vec3( 0.3333f ) );
			const float3 ColorAdjustment = ( Color.rgb - Average ) * ContrastFactor + 
				Average + FogOfWarBrightness;
			const float3 BlueShift = float3(0.0, 0.002, 0.01) * Alpha;
			return saturate( lerp( Color, ColorAdjustment + BlueShift, Alpha ) );
		}

		float3 FogOfWarBlend( float3 Color, float Alpha )
		{		
			float4 ColorAndAlpha = FOG_OF_WAR_BLEND_FUNCTION( Alpha );
			float3 ColorAdjustment = FogOfWarColorAdjustment( Color, ColorAndAlpha.a );
			return lerp( ColorAdjustment, ColorAndAlpha.rgb, ColorAndAlpha.a );
		}
		
		float3 FogOfWarBlendWithRing( float3 Color, float Alpha, float TransitionRing, float RingAlphaMultiplier )
		{		
			float4 ColorAndAlpha = FOG_OF_WAR_BLEND_FUNCTION( Alpha );
			float3 ColorAdjustment = FogOfWarColorAdjustment( Color, ColorAndAlpha.a );
			
			float3 RingColor = float3(0.0108, 0.012, 0.017);
			float3 BlendedColor = lerp( ColorAdjustment, ColorAndAlpha.rgb, ColorAndAlpha.a );
			return lerp( BlendedColor, RingColor, TransitionRing * ColorAndAlpha.a * RingAlphaMultiplier );
		}

		// Immediate mode
		float3 JominiApplyFogOfWar( in float3 Color, in float3 Coordinate, PdxTextureSampler2D FogOfWarAlphaMask )
		{
		#ifdef JOMINI_DISABLE_FOG_OF_WAR
			return Color;
		#else
			float TransitionRing;
			float Alpha = GetFogOfWarAlphaWithTransitionRing( Coordinate, FogOfWarAlphaMask, TransitionRing );
			return FogOfWarBlendWithRing( Color, Alpha, TransitionRing, 1.3f );
		#endif
		}
		
		float3 JominiApplyFogOfWarMultiSampled( in float3 Color, in float3 Coordinate, PdxTextureSampler2D FogOfWarAlphaMask )
		{
		#ifdef JOMINI_DISABLE_FOG_OF_WAR
			return Color;
		#else
			float TransitionRing;
			float Alpha = GetFogOfWarAlphaWithTransitionRing( Coordinate, FogOfWarAlphaMask, TransitionRing );
			return FogOfWarBlendWithRing( Color, Alpha, TransitionRing, 0.7f );
		#endif
		}
		
		// Post process
		float4 JominiApplyFogOfWar( in float3 WorldSpacePos, PdxTextureSampler2D FogOfWarAlphaMask )
		{
		#ifdef JOMINI_DISABLE_FOG_OF_WAR
			return float4( vec3(0.0), 1.0 );
		#else
			return FOG_OF_WAR_BLEND_FUNCTION( GetFogOfWarAlpha( WorldSpacePos, FogOfWarAlphaMask ) );
		#endif
		}
		
		#ifndef ApplyFogOfWar		
		#define ApplyFogOfWar JominiApplyFogOfWar
		#endif
		#ifndef ApplyFogOfWarMultiSampled		
		#define ApplyFogOfWarMultiSampled JominiApplyFogOfWarMultiSampled
		#endif
	]]
}
