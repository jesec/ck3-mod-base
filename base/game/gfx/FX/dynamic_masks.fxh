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

		// WINTER_GRAPHICS_WINTER_LEVELS harsh = 1.0 (normal = 0.6)
		static const float HARSH_WINTER_SEVERITY_THRESHOLD = 0.6f;

		struct SSnowEffectData
		{
			float 	_NoSnowMask;
			float 	_Noise;
			float 	_Noise1;
			float	_Noise2;
			float	_Noise3;
			float	_SnowHemisphere;
			float	_Height;
			float	_GameSnow;
			float	_GameSnowMask;
			float	_Winter;
			float	_HarshWeight;
			float	_HarshWinter;
		};

		float CombineSnowLayers( float BaseSnow, float AddedSnow )
		{
			return saturate( BaseSnow + AddedSnow - BaseSnow * AddedSnow );
		}

		float GetWinterValue()
		{
			// Convert day of year to snow
			float WinterValue = _SnowValue;
			WinterValue += _DebugSeasonWinter;
			WinterValue *= 1.5f;
			return min( 1.0f, WinterValue + WinterValue * _SnowExtent );
		}
		SSnowEffectData GetSnowEffectData( float2 MapCoords, float2 WorldSpacePosXz )
		{
			SSnowEffectData SnowEffectData;
			SnowEffectData._NoSnowMask = 1.0f - PdxTex2D( SnowMaskMap, float2( MapCoords.x, 1.0f - MapCoords.y ) ).r;
			float2 Coords = float2( MapCoords.x , MapCoords.y ) + vec2( _SnowRandomNumber ) * 0.1f;
			SnowEffectData._Noise = 1.0f - SampleNoTile( SnowMaskMap, MapCoords * 5.0 ).a;
			float4 SnowMaskColor = SampleNoTile( SnowMaskMap, Coords * _SnowNoiseTiling );
			SnowEffectData._Noise1 =  SnowMaskColor.b;
			SnowEffectData._Noise2 = SnowMaskColor.b * SnowMaskColor.g;
			SnowEffectData._Noise3 = SnowMaskColor.g;
			SnowEffectData._SnowHemisphere = RemapClamped( 1.0f - MapCoords.y, 0.0f, 1.0f, 0.0f, 1.0f );
			// Mountains etc.
			float Height = GetHeight( WorldSpacePosXz );
			SnowEffectData._Height = RemapClamped( Height, _SnowTerrainHeightMin, _SnowTerrainHeightMax, 0.0f, 1.0f );
			SnowEffectData._GameSnow = GetWinterSeverityValue( MapCoords );
			SnowEffectData._GameSnowMask = smoothstep( _SnowGameMaskMin, _SnowGameMaskMax, SnowEffectData._GameSnow ) * _SnowGameMaskImpact * SnowEffectData._Noise;
			SnowEffectData._Winter = GetWinterValue();
			SnowEffectData._Winter = saturate( SnowEffectData._Winter + SnowEffectData._GameSnowMask - SnowEffectData._Winter * SnowEffectData._GameSnowMask );
			SnowEffectData._HarshWeight = RemapClamped( SnowEffectData._GameSnow, HARSH_WINTER_SEVERITY_THRESHOLD, 0.8f, 0.0f, 1.0f );
			SnowEffectData._HarshWinter = max( SnowEffectData._Winter, SnowEffectData._GameSnow );
			return SnowEffectData;
		}

		float GetWinterMask( float WinterValue, float Position, float Contrast, float HemiPosition, float HemiContrast, SSnowEffectData SnowEffectData, float Harshness = 0.0f, float GameSnowMask = 0.0f, float ResultScale = 1.0f )
		{
			// Squish start-to-end from top of the map
			float WinterMask = LevelsScan( WinterValue - SnowEffectData._SnowHemisphere , HemiPosition, HemiContrast );
			WinterMask = lerp( WinterMask, WinterMask + _SnowTerrainHeightAdd, SnowEffectData._Height * WinterMask );

			float SnowMask = saturate( WinterMask + GameSnowMask - WinterMask * GameSnowMask );

			float Noise = Overlay( SnowEffectData._Noise1 + SnowMask, SnowEffectData._Noise2 );
			Noise = LevelsScan( Noise, Position - Harshness, Contrast + Harshness );
			Noise = Noise * SnowMask * SnowEffectData._NoSnowMask;

			return Noise * ResultScale;
		}

		float GetHarshWinterMask( float Position, float Contrast, float HemiPosition, float HemiContrast, SSnowEffectData SnowEffectData )
		{
			if ( SnowEffectData._HarshWeight <= 0.001f )
			{
				return 0.0f;
			}

			return GetWinterMask( SnowEffectData._HarshWinter, Position, Contrast, HemiPosition, HemiContrast, SnowEffectData, SnowEffectData._GameSnow, SnowEffectData._GameSnowMask, SnowEffectData._HarshWeight );
		}

		void ApplySnowMaterialTerrain( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float3 TerrainNormal, in float2 WorldSpacePosXz, in float2 MapCoords, inout float HighlightMask )
		{
			if ( _TerrainEffectsEnabled < 0.001f )
			{
				HighlightMask = 0.0f;
				return;
			}
			// Snow data
			SSnowEffectData SnowEffectData = GetSnowEffectData( MapCoords, WorldSpacePosXz );

			if ( SnowEffectData._NoSnowMask < 0.05f )
			{
				HighlightMask = 0.0f;
				return;
			}

			float Snow = GetWinterMask( SnowEffectData._Winter, _SnowTerrainAreaPosition, _SnowTerrainAreaContrast, _SnowHemispherePosition, _SnowHemisphereContrast, SnowEffectData, SnowEffectData._GameSnowMask, SnowEffectData._GameSnowMask );
			float SnowHarsh = GetHarshWinterMask( _SnowTerrainAreaPosition, _SnowTerrainAreaContrast, _SnowHemispherePosition, _SnowHemisphereContrast, SnowEffectData );
			SnowHarsh = SnowHarsh * ( 1.4f - 0.4f * SnowHarsh );
			Snow = CombineSnowLayers( Snow, SnowHarsh );
			float Frost = GetWinterMask( SnowEffectData._Winter, _FrostTerrainAreaPosition, _FrostTerrainAreaContrast, _FrostHemispherePosition, _FrostHemisphereContrast, SnowEffectData, 0.0f, SnowEffectData._GameSnowMask );
			float WinterSmoothstep = smoothstep( 0.0f, 0.1f, SnowEffectData._Winter );
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
			BlendValue = CombineSnowLayers( BlendValue, SnowHarsh );

			// Snow Layer
			Diffuse = lerp( Diffuse, SnowDiffuse, BlendValue );
			Normal = lerp( Normal, SnowNormal, BlendValue );
			Properties = lerp( Properties, SnowProperties, BlendValue );

			#if defined( DEBUG_OLD_SNOW_MASK )
				DebugOldSnowMask( Diffuse.rgb, MapCoords );
			#endif
		}

		void ApplySnowMaterial( inout float3 Diffuse, inout float4 Properties, inout float3 Normal, in float2 WorldSpacePosXz, in SSnowEffectData SnowEffectData, inout float HighlightMask, in float BlendStrength )
		{
			#ifdef LOW_SPEC_SHADERS
				HighlightMask = 0.0f;
				return;
			#endif
			if ( _TerrainEffectsEnabled < 0.001f )
			{
				HighlightMask = 0.0f;
				return;
			}

			if ( SnowEffectData._NoSnowMask < 0.05f )
			{
				HighlightMask = 0.0f;
				return;
			}

			float Snow = GetWinterMask( SnowEffectData._Winter, _SnowAreaPosition, _SnowAreaContrast, _SnowHemispherePosition, _SnowHemisphereContrast, SnowEffectData, SnowEffectData._GameSnowMask, SnowEffectData._GameSnowMask );
			float SnowHarsh = GetHarshWinterMask( _SnowTerrainAreaPosition, _SnowTerrainAreaContrast, _SnowHemispherePosition, _SnowHemisphereContrast, SnowEffectData );
			SnowHarsh = SnowHarsh * ( 1.4f - 0.4f * SnowHarsh );
			Snow = CombineSnowLayers( Snow, SnowHarsh );
			Snow *= smoothstep( 0.0f, 0.1f, SnowEffectData._Winter );

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

		void ApplySnowMaterialMesh( inout float3 Diffuse, inout float4 Properties, inout float3 Normal, in float2 WorldSpacePosXz, in float2 MapCoords, inout float HighlightMask, in float BlendStrength )
		{
			SSnowEffectData SnowEffectData = GetSnowEffectData( MapCoords, WorldSpacePosXz );
			ApplySnowMaterial( Diffuse, Properties, Normal, WorldSpacePosXz, SnowEffectData, HighlightMask, BlendStrength );
		}

		void ApplySnowMaterialWithSnowEffectData( in SSnowEffectData SnowEffectData, inout float3 Diffuse, inout float4 Properties, inout float3 Normal, in float2 WorldSpacePosXz, inout float HighlightMask, in float BlendStrength )
		{
			ApplySnowMaterial( Diffuse, Properties, Normal, WorldSpacePosXz, SnowEffectData, HighlightMask, BlendStrength );
		}

		void ApplySnowMaterialRoad( inout float4 Diffuse, inout float4 Properties, float3 TerrainNormal, in float2 WorldSpacePosXz, in float2 MapCoords, inout float HighlightMask )
		{
			if ( _TerrainEffectsEnabled < 0.001f )
			{
				HighlightMask = 0.0f;
				return;
			}
			// Snow data
			SSnowEffectData SnowEffectData = GetSnowEffectData( MapCoords, WorldSpacePosXz );

			if ( SnowEffectData._NoSnowMask < 0.05f )
			{
				HighlightMask = 0.0f;
				return;
			}

			float Snow = GetWinterMask( SnowEffectData._Winter, _SnowTerrainAreaPosition, _SnowTerrainAreaContrast, _SnowHemispherePosition, _SnowHemisphereContrast, SnowEffectData, SnowEffectData._GameSnowMask, SnowEffectData._GameSnowMask );
			float SnowHarsh = GetHarshWinterMask( _SnowTerrainAreaPosition, _SnowTerrainAreaContrast, _SnowHemispherePosition, _SnowHemisphereContrast, SnowEffectData );
			SnowHarsh = SnowHarsh * ( 1.4f - 0.4f * SnowHarsh );
			Snow = CombineSnowLayers( Snow, SnowHarsh );
			float Frost = GetWinterMask( SnowEffectData._Winter, _FrostTerrainAreaPosition, _FrostTerrainAreaContrast, _FrostHemispherePosition, _FrostHemisphereContrast, SnowEffectData, 0.0f, SnowEffectData._GameSnowMask );
			float WinterSmoothstep = smoothstep( 0.0f, 0.1f, SnowEffectData._Winter );
			Frost *= _FrostMultiplier * WinterSmoothstep * 0.5f;
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
			float4 SnowDiffuse = SampleNoTile( DetailTextures, SnowUV, _SnowTexIndex );;
			float4 SnowProperties = SampleNoTile( MaterialTextures, SnowUV, _SnowTexIndex );

			// Terrain material blend
			SnowDiffuse.a = 1.0f - lerp( 1.0f, SnowDiffuse.a, 1.0f - _SnowHeightWeight );
			SnowDiffuse.a *= SnowEffectData._Noise3;
			float2 BlendFactors = CalcHeightBlendFactors( float2( Diffuse.a, SnowDiffuse.a ), float2( 1.0f - Snow, Snow ), DetailBlendRange * _SnowHeightContrast * Snow );

			// Initial Frost Layer
			Diffuse = lerp( Diffuse, SnowDiffuse, Frost );
			Properties = lerp( Properties, SnowProperties, Frost );

			float BlendValue = BlendFactors.y;
			BlendValue = 1 - pow( 1 - BlendValue, 0.25f );
			BlendValue = BlendValue - smoothstep( 0.25f, 1.0f, SnowEffectData._Noise2 ) * 2.0f;
			BlendValue = max( 0.000001f, BlendValue );
			BlendValue = CombineSnowLayers( BlendValue, SnowHarsh );

			// Snow Layer
			Diffuse = lerp( Diffuse, SnowDiffuse, BlendValue );
			Properties = lerp( Properties, SnowProperties, BlendValue );

			#if defined( DEBUG_OLD_SNOW_MASK )
				DebugOldSnowMask( Diffuse.rgb, MapCoords );
			#endif
		}

		float3 ApplySnowDiffuse( in float3 TerrainColor, in float3 Normal, in float2 Coordinate )
		{
			if ( _TerrainEffectsEnabled < 0.001f )
			{
				return TerrainColor;
			}
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
			if ( _TerrainEffectsEnabled < 0.001f )
			{
				SnowMask = 0.0f;
				return TerrainColor;
			}
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
