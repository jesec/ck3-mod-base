Includes = {
	"cw/utility.fxh"
	"cw/pdxterrain.fxh"
	"standardfuncsgfx.fxh"
	"utility_game.fxh"
	"province_effects.fxh"
}

#ifndef WINTER_COMBINED_TEXTURE
TextureSampler SnowMaskMap
{
	Index = 9
	MagFilter = "Linear"
	MinFilter = "Linear"
	MipFilter = "Linear"
	SampleModeU = "Wrap"
	SampleModeV = "Wrap"
	File = "gfx/map/textures/snow_mask.dds"
	sRGB = no
}
#endif
TextureSampler WinterTexture
{
	Ref = WinterTexture
	MagFilter = "Linear"
	MinFilter = "Linear"
	MipFilter = "Linear"
	SampleModeU = "Wrap"
	SampleModeV = "Wrap"
}

PixelShader =
{
	Code
	[[
		// Debug the game snow mask | Blue = Mild, Green = Normal, Red = Harsh
		//#define DEBUG_OLD_SNOW_MASK

#ifndef WINTER_COMBINED_TEXTURE
		float4 GetSnowDiffuseValue( in float2 Coordinate )
		{
			return PdxTex2D( DetailTextures, float3( Coordinate, _SnowTexIndex ) );
		}
		float GetWinterSeverityValue( in float2 Coordinate )
		{
			return float4( PdxTex2D( WinterTexture, Coordinate ) ).r;
		}
#else
		// The WinterTexture combines the two winter textures, to save one sampler (relevant on macOS with OpenGL):
		// - the winter severity value is in blue, this is what WinterTexture is without this define
		// - SnowDiffuseMap is in red, green, and alpha. We take its blue value from green, because we assume they are basically the same.
		// The texture isn't marked as sRGB, so we undo the double gamma correction for the diffuse value.
		float4 GetSnowDiffuseValue( in float2 Coordinate )
		{
			return ToLinear( PdxTex2D( WinterTexture, Coordinate ).rgga );
		}
		float GetWinterSeverityValue( in float2 Coordinate )
		{
			return PdxTex2D( WinterTexture, Coordinate ).b;
		}
#endif
		void DebugOldSnowMask( inout float3 Diffuse, float2 MapCoords )
		{
			// Snow area
			float SnowOld = GetWinterSeverityValue( MapCoords );

			float MILD_Threshhold = 0.2f;
			float NORMAL_Threshhold = 0.6f;
			float HARSH_Threshhold = 0.9f;
			float3 MILD = float3( 0.0f, 0.0f, 1.0f );
			float3 NORMAL = float3( 0.0f, 1.0f, 0.0f );
			float3 HARSH = float3( 1.0f, 0.0f, 0.0f );
			float MILD_Mask = RemapClamped( SnowOld, 0.0f, MILD_Threshhold, 0.0f, 1.0f );
			float NORMAL_Mask =  RemapClamped( SnowOld, MILD_Threshhold, NORMAL_Threshhold, 0.0f, 1.0f  );
			float HARSH_Mask =  RemapClamped( SnowOld, NORMAL_Threshhold, HARSH_Threshhold, 0.0f, 1.0f  );
			float3 SnowDebug = vec3( 0.0f );
			SnowDebug = lerp( SnowDebug, MILD, MILD_Mask );
			SnowDebug = lerp( SnowDebug, NORMAL, NORMAL_Mask );
			SnowDebug = lerp( SnowDebug, HARSH, HARSH_Mask );

			Diffuse = lerp( Diffuse, ToGamma( SnowDebug ), 1.0f );
		}

		struct SSnowEffectData
		{
			float 	_NoSnowMask;
			float 	_Noise;
			float	_Noise2;
			float	_Noise3;
			float	_SnowHemisphere;
			float	_Height;
		};

		float GetWinterValue()
		{
			// Convert day of year to snow
			float WinterValue = _SnowValue;
			WinterValue += _DebugSeasonWinter;
			WinterValue *= 1.5f;
			return min( 1.0f, WinterValue + WinterValue * _SnowExtent );
		}
		void GetSnowEffectData( inout SSnowEffectData SnowEffectData, float2 MapCoords, float2 WorldSpacePosXz )
		{
			float2 Coords = float2( MapCoords.x , MapCoords.y ) + vec2( _SnowRandomNumber ) * 0.1f;			
			float4 SnowMaskColor = SampleNoTile( SnowMaskMap, Coords * _SnowNoiseTiling );
			SnowEffectData._Noise =  SnowMaskColor.b;
			SnowEffectData._Noise3 = SnowMaskColor.g;
			SnowEffectData._Noise2 = SnowMaskColor.b * SnowMaskColor.g;
			SnowEffectData._SnowHemisphere = RemapClamped( 1.0f - MapCoords.y, 0.0f, 1.0f, 0.0f, 1.0f );
			// Mountains etc.
			float Height = GetHeight( WorldSpacePosXz );
			SnowEffectData._Height = RemapClamped( Height, _SnowTerrainHeightMin, _SnowTerrainHeightMax, 0.0f, 1.0f );
		}

		float GetWinterMask( float WinterValue, float2 MapCoords, float Position, float Contrast, float HemiPosition, float HemiContrast, SSnowEffectData SnowEffectData, float Harshness = 0.0f, float GameSnowMask = 0.0f)
		{
			// Squish start-to-end from top of the map
			float WinterMask = LevelsScan( WinterValue - SnowEffectData._SnowHemisphere , HemiPosition, HemiContrast );
			WinterMask = lerp( WinterMask, WinterMask + _SnowTerrainHeightAdd, SnowEffectData._Height * WinterMask );

			float SnowMask = saturate( WinterMask + GameSnowMask - WinterMask * GameSnowMask );

			float Noise = Overlay( SnowEffectData._Noise + SnowMask, SnowEffectData._Noise2 );
			Noise = LevelsScan( Noise, Position - Harshness, Contrast + Harshness );
			Noise = Noise * SnowMask * SnowEffectData._NoSnowMask;

			return Noise;
		}

		void ApplySnowMaterialTerrain( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float3 TerrainNormal, in float2 WorldSpacePosXz, in float2 MapCoords, inout float HighlightMask )
		{
			// Snow data
			SSnowEffectData SnowEffectData;
			SnowEffectData._NoSnowMask = 1.0f - PdxTex2D( SnowMaskMap, float2( MapCoords.x, 1.0f - MapCoords.y) ).r;
			GetSnowEffectData( SnowEffectData, MapCoords, WorldSpacePosXz );

			if ( SnowEffectData._NoSnowMask < 0.05f )
			{
				HighlightMask = 0.0f;
				return;
			}

			// UVs
			float Noise = 1.0f - SampleNoTile( SnowMaskMap, MapCoords * 5.0 ).a;
			float GameSnow = GetWinterSeverityValue( MapCoords );
			float GameSnowMask = smoothstep( _SnowGameMaskMin, _SnowGameMaskMax, GameSnow ) * _SnowGameMaskImpact * Noise;
			float Winter = GetWinterValue();
			Winter = saturate( Winter + GameSnowMask - Winter * GameSnowMask );

			float Snow = GetWinterMask( Winter, MapCoords, _SnowTerrainAreaPosition, _SnowTerrainAreaContrast, _SnowHemispherePosition, _SnowHemisphereContrast, SnowEffectData, GameSnowMask, GameSnowMask );
			float Frost = GetWinterMask( Winter, MapCoords, _FrostTerrainAreaPosition, _FrostTerrainAreaContrast, _FrostHemispherePosition, _FrostHemisphereContrast, SnowEffectData, 0.0f, GameSnowMask );
			float WinterSmoothstep = smoothstep( 0.0f, 0.1f, Winter );
			Frost *= _FrostMultiplier * WinterSmoothstep;
			Snow *= WinterSmoothstep;

			if ( Snow < SKIP_VALUE && Frost < SKIP_VALUE )
			{
				HighlightMask = Snow;
				return;
			}
			// Remove snow from steep angle
			TerrainNormal.y = smoothstep( _SnowAngleRemove, 1.0f, abs( TerrainNormal.y ) );
			Snow = lerp( 0.0f, Snow, TerrainNormal.y );
			HighlightMask = Snow;

			// Apply material
			float2 DetailUV = CalcDetailUV( WorldSpacePosXz );
			float2 SnowUV = DetailUV * _SnowTextureTiling;
			float4 SnowDiffuse = SampleNoTile( DetailTextures, SnowUV, _SnowTexIndex );
			float4 SnowNormalRRxG = SampleNoTile( NormalTextures, SnowUV, _SnowTexIndex );
			float3 SnowNormal = UnpackRRxGNormal( SnowNormalRRxG ).xyz;
			float4 SnowProperties = SampleNoTile( MaterialTextures, SnowUV, _SnowTexIndex );

			// Terrain material blend
			Diffuse.a = lerp( 0.0f, Diffuse.a, _SnowHeightWeight );
			SnowDiffuse.a = 1.0f - lerp( 1.0f, SnowDiffuse.a, 1.0f - _SnowHeightWeight );
			SnowDiffuse.a *= SnowEffectData._Noise3;
			float2 BlendFactors = CalcHeightBlendFactors( float2( Diffuse.a, SnowDiffuse.a ), float2( 1.0f - Snow, Snow ), DetailBlendRange * _SnowHeightContrast * Snow );

			// Initial Frost Layer
			Diffuse = lerp( Diffuse, SnowDiffuse, Frost );
			Normal = lerp( Normal, SnowNormal, Frost );
			Properties = lerp( Properties, SnowProperties, Frost );

			float BlendValue = BlendFactors.y;
			BlendValue = 1 - pow( 1 - BlendValue, 5 );

			// Add more details to the snow
			float DetailAngleReduction = smoothstep( 0.0f, 0.02f, abs( Normal.y ) );
			DetailAngleReduction = lerp( 0.5f, 0.0f, DetailAngleReduction );
			DetailAngleReduction = clamp( DetailAngleReduction * Snow, 0.0f, 1.0f );
			BlendValue = lerp( BlendValue, 0.0f, DetailAngleReduction );
			BlendValue = BlendValue - smoothstep( 0.25f, 1.0f, SnowEffectData._Noise2 ) * 2.0f;
			BlendValue = max( 0.000001f, BlendValue );

			// Snow Layer
			Diffuse = lerp( Diffuse, SnowDiffuse, BlendValue );
			Normal = lerp( Normal, SnowNormal, BlendValue );
			Properties = lerp( Properties, SnowProperties, BlendValue );

			#if defined( DEBUG_OLD_SNOW_MASK )
				DebugOldSnowMask( Diffuse.rgb, MapCoords );
			#endif
		}

		void ApplySnowMaterialMesh( inout float3 Diffuse, inout float4 Properties, inout float3 Normal, in float2 WorldSpacePosXz, in float2 MapCoords, inout float HighlightMask, in float BlendStrength )
		{
			#ifdef LOW_SPEC_SHADERS
				HighlightMask = 0.0f;
				return;
			#endif

			SSnowEffectData SnowEffectData;
			SnowEffectData._NoSnowMask = 1.0f - PdxTex2D( SnowMaskMap, float2( MapCoords.x, 1.0f - MapCoords.y ) ).r;
			GetSnowEffectData( SnowEffectData, MapCoords, WorldSpacePosXz );
			if ( SnowEffectData._NoSnowMask < 0.05f )
			{
				HighlightMask = 0.0f;
				return;
			}

			// UVs
			float Noise = 1.0f - SampleNoTile( SnowMaskMap, MapCoords * 5.0 ).a;
			float GameSnow = GetWinterSeverityValue( MapCoords );
			float GameSnowMask = smoothstep( _SnowGameMaskMin, _SnowGameMaskMax, GameSnow ) * _SnowGameMaskImpact * Noise;

			float Winter = GetWinterValue();
			Winter = saturate( Winter + GameSnowMask - Winter * GameSnowMask );

			float Snow = GetWinterMask( Winter, MapCoords, _SnowAreaPosition, _SnowAreaContrast, _SnowHemispherePosition, _SnowHemisphereContrast, SnowEffectData, GameSnowMask, GameSnowMask );
			Snow *= smoothstep( 0.0f, 0.1f, Winter );

			if ( Snow < SKIP_VALUE )
			{
				HighlightMask = Snow;
				return;
			}
			// Remove snow from steep angle
			Normal.y = smoothstep( _SnowAngleRemove, 1.0f, abs( Normal.y ) );
			Snow = lerp( 0.0f, Snow, Normal.y );

			// Apply material
			float2 DetailUV = CalcDetailUV( WorldSpacePosXz );
			float2 SnowUV = DetailUV * 0.5f * _SnowTextureTiling;
			float3 SnowDiffuse = SampleNoTile( DetailTextures, SnowUV , _SnowTexIndex ).rgb;
			float4 SnowProperties = SampleNoTile( MaterialTextures, SnowUV, _SnowTexIndex );

			float BlendValue = 1 - pow( 1 - Snow, BlendStrength );
			Diffuse = lerp( Diffuse, SnowDiffuse, BlendValue );
			Properties = lerp( Properties, SnowProperties, BlendValue );

			HighlightMask = Snow;
		}

		float3 ApplySnowDiffuse( in float3 TerrainColor, in float3 Normal, in float2 Coordinate )
		{
			float SnowScale = 150.0f;
			float SnowScaleLarge = 0.0f;
			float SnowScaleMedium = SnowScale;
			float SnowScaleSmall = SnowScale * 0.32345f;

			float2 MapDimensions = float2( 2.0f, 1.0f );

			float2 SnowUVLarge = Coordinate * MapDimensions * SnowScaleLarge;
			float2 SnowUVMedium = Coordinate * MapDimensions * SnowScaleMedium;
			float2 SnowUVSmall = Coordinate * MapDimensions *SnowScaleSmall;

			float4 SnowDiffuseMedium = GetSnowDiffuseValue( SnowUVMedium );
			float SnowDiffuseLarge = GetSnowDiffuseValue( SnowUVLarge ).a;
			float SnowDiffuseSmall = GetSnowDiffuseValue( SnowUVSmall ).a;

			float SnowMask = GetWinterSeverityValue( Coordinate ) * 0.6f;

			float SnowAlpha = 0.0f;
			SnowAlpha = Overlay( SnowDiffuseLarge, SnowDiffuseMedium.a );
			SnowAlpha = Overlay( SnowAlpha, SnowDiffuseSmall );
			SnowAlpha = ToLinear( SnowAlpha );

			float GradientWidth = 0.3f;
			float GradientWidthHalf = GradientWidth * 0.5f;

			SnowAlpha = RemapClamped( SnowAlpha, 0.0f, 1.0f, GradientWidthHalf, 1.0f - GradientWidthHalf );
			SnowAlpha = clamp( SnowAlpha, 0.0f, 1.0f );

			SnowMask = LevelsScan( SnowAlpha, 1.0f - SnowMask, GradientWidth );

			SnowMask *= clamp( Normal.g * Normal.g, 0.0f, 1.0f );
			return lerp( TerrainColor, SnowDiffuseMedium.rgb, SnowMask );
		}

		float3 ApplySnowDiffuse( in float3 TerrainColor, in float3 Normal, in float2 Coordinate, out float SnowMask )
		{
			float SnowScale = 150.0f;
			float SnowScaleLarge = 0.0f;
			float SnowScaleMedium = SnowScale;
			float SnowScaleSmall = SnowScale * 0.32345f;

			float2 MapDimensions = float2( 2.0f, 1.0f );

			float2 SnowUVLarge = Coordinate * MapDimensions * SnowScaleLarge;
			float2 SnowUVMedium = Coordinate * MapDimensions * SnowScaleMedium;
			float2 SnowUVSmall = Coordinate * MapDimensions * SnowScaleSmall;

			float4 SnowDiffuseMedium = GetSnowDiffuseValue( SnowUVMedium );
			float SnowDiffuseLarge = GetSnowDiffuseValue( SnowUVLarge ).a;
			float SnowDiffuseSmall = GetSnowDiffuseValue( SnowUVSmall ).a;

			SnowMask = GetWinterSeverityValue( Coordinate ) * 0.6f;

			float SnowAlpha = 0.0f;
			SnowAlpha = Overlay( SnowDiffuseLarge, SnowDiffuseMedium.a );
			SnowAlpha = Overlay( SnowAlpha, SnowDiffuseSmall );
			SnowAlpha = ToLinear( SnowAlpha );

			float GradientWidth = 0.3f;
			float GradientWidthHalf = GradientWidth * 0.5f;

			SnowAlpha = RemapClamped( SnowAlpha, 0.0f, 1.0f, GradientWidthHalf, 1.0f - GradientWidthHalf );
			SnowAlpha = clamp( SnowAlpha, 0.0f, 1.0f );

			SnowMask = LevelsScan( SnowAlpha, 1.0f - SnowMask, GradientWidth );

			SnowMask *= clamp( Normal.g * Normal.g, 0.0f, 1.0f );
			return lerp( TerrainColor, SnowDiffuseMedium.rgb, SnowMask );
		}

		float3 ApplyDynamicMasksDiffuse( in float3 TerrainColor, in float3 Normal, in float2 Coordinate )
		{
			TerrainColor = ApplySnowDiffuse( TerrainColor, Normal, Coordinate );

			return TerrainColor;
		}

		float3 ApplyDynamicMasksDiffuse( in float3 TerrainColor, in float3 Normal, in float2 Coordinate, inout float Snow )
		{
			TerrainColor = ApplySnowDiffuse( TerrainColor, Normal, Coordinate, Snow );

			return TerrainColor;
		}
	]]
}
