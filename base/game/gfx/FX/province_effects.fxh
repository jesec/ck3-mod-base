Includes = {
	"cw/pdxterrain.fxh"
	"jomini/jomini_province_overlays.fxh"
	"province_effects_variables.fxh"
}

struct EffectIntensities
{
	float _Drought;
	float _Flood;
	float _Summer;
	float _Snow;
};

PixelShader =
{
	TextureSampler ProvinceEffectsNoise
	{
		Index = 14
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		File = "gfx/map/textures/wavy_noise.dds"
	}

	BufferTexture ProvinceEffectDataBuffer
	{
		Ref = ProvinceEffectData
		type = float4
	}

	Code
	[[
		// Enable to debug mask
		// #define DEBUG_PROVINCE_EFFECT_MASK_DROUGHT
		// #define DEBUG_PROVINCE_EFFECT_MASK_FLOOD
		// #define DEBUG_PROVINCE_EFFECT_MASK_SUMMER
		// #define DEBUG_PROVINCE_EFFECT_MASK_SNOW

		static const float3 UP_VECTOR = float3( 0.0f, 1.0f, 0.0f );
		static const float SKIP_VALUE = 0.001f;

		void DebugCondition( inout float3 Diffuse, EffectIntensities ConditionData )
		{
			#if defined( DEBUG_PROVINCE_EFFECT_MASK_DROUGHT )
				Diffuse.rgb = lerp( Diffuse.rgb, float3( 1.0f, 0.0f, 0.0f ), ConditionData._Drought );
			#endif

			#if defined( DEBUG_PROVINCE_EFFECT_MASK_FLOOD )
				Diffuse.rgb = lerp( Diffuse.rgb, float3( 0.0f, 0.0f, 1.0f ), ConditionData._Flood );
			#endif

			#if defined( DEBUG_PROVINCE_EFFECT_MASK_SUMMER )
				Diffuse.rgb = lerp( Diffuse.rgb, float3( 0.0f, 0.0f, 1.0f ), ConditionData._Summer );
			#endif

			#if defined( DEBUG_PROVINCE_EFFECT_MASK_SNOW )
				Diffuse.rgb = lerp( Diffuse.rgb, float3( 1.0f, 1.0f, 0.0f ), ConditionData._Snow );
			#endif
		}

		float3 AdjustHsv( float3 Rgb, float Hue, float Saturation, float Value )
		{
			float3 Color = RGBtoHSV( Rgb );
			Color.x += Hue;
			Color.y *= Saturation;
			Color.z *= Value;
			return HSVtoRGB( Color );
		}

		float3 AdjustSaturation( float3 Rgb, float Saturation )
		{
			return AdjustHsv( Rgb, 0.0f, Saturation, 1.0f );
		}

		float4 SampleProvinceEffects( float2 MapCoords )
		{
			float2 ColorIndex = PdxTex2D( ProvinceColorIndirectionTexture, MapCoords ).rg;
			int Index = ColorIndex.x * 255.0f + ColorIndex.y * 255.0f * 256.0f;
			return PdxReadBuffer4( ProvinceEffectDataBuffer, Index );
		}

		void SampleProvinceEffectsMask( float2 MapCoords, inout EffectIntensities ConditionData )
		{
			// ProvinceEffects mask
			float2 Pixel = MapCoords * IndirectionMapSize + 0.5f;
			float2 FracCoord = frac( Pixel );
			Pixel = floor( Pixel ) / IndirectionMapSize - InvIndirectionMapSize / 2.0f;
			float4 C11 = SampleProvinceEffects( Pixel );
			float4 C21 = SampleProvinceEffects( Pixel + float2( InvIndirectionMapSize.x, 0.0f ) );
			float4 C12 = SampleProvinceEffects( Pixel + float2( 0.0f, InvIndirectionMapSize.y ) );
			float4 C22 = SampleProvinceEffects( Pixel + InvIndirectionMapSize );

			// Bilinear interpolation
			float x1 = lerp( C11.g, C21.g, FracCoord.x );
			float x2 = lerp( C12.g, C22.g, FracCoord.x );

			// Opacity
			float Impact = lerp( x1, x2, FracCoord.y );
			Impact = RemapClamped( lerp( x1, x2, FracCoord.y ), 0.0, OpacityLowImpactValue, 0.0, 0.5 );
			Impact += RemapClamped( lerp( x1, x2, FracCoord.y ), OpacityLowImpactValue, OpacityHighImpactValue, 0.0, 0.5 );

			// ProvinceEffects condition filtering
			float Dro1 = lerp( C11.r == DROUGHT_INDEX, C21.r == DROUGHT_INDEX, FracCoord.x );
			float Dro2 = lerp( C12.r == DROUGHT_INDEX, C22.r == DROUGHT_INDEX, FracCoord.x );
			ConditionData._Drought = lerp( Dro1, Dro2, FracCoord.y ) * Impact;

			float Flo1 = lerp( C11.r == FLOOD_INDEX, C21.r == FLOOD_INDEX, FracCoord.x );
			float Flo2 = lerp( C12.r == FLOOD_INDEX, C22.r == FLOOD_INDEX, FracCoord.x );
			ConditionData._Flood = lerp( Flo1, Flo2, FracCoord.y ) * Impact;

			float Sum1 = lerp( C11.r == SUMMER_INDEX, C21.r == SUMMER_INDEX, FracCoord.x );
			float Sum2 = lerp( C12.r == SUMMER_INDEX, C22.r == SUMMER_INDEX, FracCoord.x );
			ConditionData._Summer = lerp( Sum1, Sum2, FracCoord.y ) * Impact;

			float Snow1 = lerp( C11.r == SNOW_INDEX, C21.r == SNOW_INDEX, FracCoord.x );
			float Snow2 = lerp( C12.r == SNOW_INDEX, C22.r == SNOW_INDEX, FracCoord.x );
			ConditionData._Snow = lerp( Snow1, Snow2, FracCoord.y ) * Impact;
		}

		void ApplyDroughtDiffuseTerrain( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float2 WorldSpacePosXz, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}
			float2 MapCoords = WorldSpacePosXz * WorldSpaceToTerrain0To1;
			float2 DetailUV = CalcDetailUV( WorldSpacePosXz );

			float4 DroughtDiffuse = Diffuse;
			float3 DroughtNormal = Normal;
			float4 DroughtProperties = Properties;

			float SlopeMultiplier = dot( CalculateNormal( WorldSpacePosXz ), UP_VECTOR );
			SlopeMultiplier = RemapClamped( SlopeMultiplier, DroughtSlopeMin, 1.0f, 0.0f, 1.0f );
			ConditionValue *= SlopeMultiplier;

			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float ColorPositionValue = lerp( DroughtColorMaskPositionFrom, DroughtColorMaskPositionTo, ConditionValue );
			float ColorContrastValue = lerp( DroughtColorMaskContrastFrom, DroughtColorMaskContrastTo, ConditionValue );
			float DryPositionValue = lerp( DroughtDryMaskPositionFrom, DroughtDryMaskPositionTo, ConditionValue );
			float DryContrastValue = lerp( DroughtDryMaskContrastFrom, DroughtDryMaskContrastTo, ConditionValue );
			float CracksPositionValue = lerp( DroughtCracksAreaMaskPositionFrom, DroughtCracksAreaMaskPositionTo, ConditionValue );
			float CracksContrastValue = lerp( DroughtCracksAreaMaskContrastFrom, DroughtCracksAreaMaskContrastTo, ConditionValue );

			// Dry patches
			float4 DryTexDiffuse = PdxTex2D( DetailTextures, float3( DetailUV, DroughtDryTexureIndex ) );
			DryTexDiffuse.a = 1.0f - DryTexDiffuse;
			float4 DryTexNormalRRxG = PdxTex2D( NormalTextures, float3( DetailUV, DroughtDryTexureIndex ) );
			float3 DryTexNormal = UnpackRRxGNormal( DryTexNormalRRxG ).xyz;
			float4 DryTexProperties = PdxTex2D( MaterialTextures, float3( DetailUV, DroughtDryTexureIndex ) );

			float2 DryMaskUV = float2( MapCoords.x * 2.0f, MapCoords.y ) * DroughtDryMaskUVTiling;
			float DryNoiseMask = PdxTex2D( ProvinceEffectsNoise, DryMaskUV ).r;

			float DryMask = LevelsScan( DryNoiseMask, DryPositionValue, DryContrastValue ) * DroughtDryTextureBlendWeight * DroughtBlendWeight;
			float2 DryBlendFactors = CalcHeightBlendFactors( float2( Diffuse.a, DryTexDiffuse.a ), float2( 1.0f - DryMask, DryMask ), DetailBlendRange );

			// Base terrain color change
			float ColorNoise = LevelsScan( DryNoiseMask, ColorPositionValue, ColorContrastValue );
			DroughtDiffuse.rgb = lerp( DroughtDiffuse.rgb, AdjustHsv( DroughtDiffuse.rgb, 0.0f, DroughtPreSaturation, DroughtPreValue ), ColorNoise );
			DroughtDiffuse.rgb = lerp( DroughtDiffuse.rgb, Overlay( DroughtDiffuse.rgb, DroughtOverlayColor ), ColorNoise );

			DryTexDiffuse.rgb = Overlay( DryTexDiffuse.rgb, DroughtDryOverlayColor );
			DroughtDiffuse.rgb = lerp( DroughtDiffuse.rgb, DryTexDiffuse.rgb, DryBlendFactors.y );
			DroughtNormal = lerp( DroughtNormal, DryTexNormal, DryBlendFactors.y );
			DroughtProperties = lerp( DroughtProperties, DryTexProperties, DryBlendFactors.y );

			// Cracks Area Mask
			float2 CrackedMaskUV = float2( MapCoords.x * 2.0f, MapCoords.y ) * DroughtCracksAreaMaskTiling;
			float CrackedMask = PdxTex2D( ProvinceEffectsNoise, CrackedMaskUV ).r;
			CrackedMask = LevelsScan( CrackedMask, CracksPositionValue, CracksContrastValue );

			// Cracked areas
			float2 CrackedTextureUV = CalcDetailUV( WorldSpacePosXz ) * DroughtCrackedTextureUVTiling;
			float4 CrackedTexDiffuse = PdxTex2D( DetailTextures, float3( CrackedTextureUV, DroughtCracksTexureIndex ) );
			CrackedTexDiffuse.rgb = Overlay( CrackedTexDiffuse.rgb, DroughtCracksOverlayColor );
			CrackedTexDiffuse.a = 1.0f - CrackedTexDiffuse.a;
			float4 CrackedTexNormalRRxG = PdxTex2D( NormalTextures, float3( CrackedTextureUV, DroughtCracksTexureIndex ) );
			float3 CrackedTexNormal = UnpackRRxGNormal( CrackedTexNormalRRxG ).xyz;
			float4 CrackedTexProperties = PdxTex2D( MaterialTextures, float3( CrackedTextureUV, DroughtCracksTexureIndex ) );
			float2 BlendFactors = CalcHeightBlendFactors( float2( Diffuse.a, CrackedTexDiffuse.a), float2( 1.0f - DroughtCracksTextureBlendWeight * DroughtBlendWeight, DroughtCracksTextureBlendWeight * DroughtBlendWeight ), DetailBlendRange * DroughtCracksTextureBlendContrast );
			DroughtDiffuse.rgb = lerp( DroughtDiffuse.rgb, CrackedTexDiffuse.rgb, BlendFactors.y * CrackedMask );
			DroughtNormal = lerp( DroughtNormal, CrackedTexNormal, BlendFactors.y * CrackedMask );
			DroughtProperties = lerp( DroughtProperties, CrackedTexProperties, BlendFactors.y * CrackedMask );

			// Color adjustment
			DroughtDiffuse.rgb = AdjustHsv( DroughtDiffuse.rgb, 0.0f, DroughtFinalSaturation, 1.0f );

			Diffuse.rgb = lerp( Diffuse.rgb, DroughtDiffuse.rgb, ConditionValue );
			Normal = lerp( Normal, DroughtNormal, ConditionValue );
			Properties = lerp( Properties, DroughtProperties, ConditionValue );
		}

		void ApplyFloodingDiffuseTerrain( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float2 WorldSpacePosXz, float ConditionValue, inout float WaterNormalLerp )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float2 MapCoords = WorldSpacePosXz * WorldSpaceToTerrain0To1;
			float2 TextureUV = MapCoords * float2( 2.0f, 1.0f );
			float2 DetailUV = CalcDetailUV( WorldSpacePosXz ) * FloodDetailTiling;

			float AdjustedPositionValue = lerp( FloodNoisePositionFrom, FloodNoisePositionTo, ConditionValue );
			float AdjustedContrastValue = lerp( FloodNoiseContrastFrom, FloodNoiseContrastTo, ConditionValue );

			float SlopeMultiplier = dot( CalculateNormal( WorldSpacePosXz ), UP_VECTOR );
			SlopeMultiplier = RemapClamped( SlopeMultiplier, FloodSlopeMin, 1.0f, 0.0f, 1.0f );

			float4 FloodTexDiffuse = PdxTex2D( DetailTextures, float3( DetailUV, FloodTextureIndex ) );
			float4 FloodTexNormalRRxG = PdxTex2D( NormalTextures, float3( DetailUV, FloodTextureIndex ) );
			float3 FloodTexNormal = UnpackRRxGNormal( FloodTexNormalRRxG ).xyz;
			float4 FloodTexProperties = PdxTex2D( MaterialTextures, float3( DetailUV, FloodTextureIndex ) );

			float2 FloodNoiseUV = TextureUV * FloodNoiseTiling;
			float FloodNoise = PdxTex2D( ProvinceEffectsNoise, FloodNoiseUV ).r;
			float FloodNoiseFill = LevelsScan( FloodNoise, AdjustedPositionValue, AdjustedContrastValue );
			FloodNoise = FloodNoiseFill * SlopeMultiplier;
			float2 FloodBlendFactors = CalcHeightBlendFactors( float2( Diffuse.a, FloodTexDiffuse.a ), float2( 1.0f - FloodNoise, FloodNoise ), DetailBlendRange * 2.0f );

			// Watercolor
			float4 FloodWaterColor = lerp( float4( FloodWaterInnerColor, 1.0f ), float4( FloodWaterEdgeColor, 1.0f ), FloodBlendFactors.y * FloodNoiseFill );

			// Apply Water Color
			float4 FloodDiffuse = lerp( Diffuse, FloodWaterColor, FloodBlendFactors.y * FloodWaterOpacity );
			float3 FloodNormal = lerp( Normal, FloodNormalDirection, FloodBlendFactors.y * FloodWaterPropertiesBlend );
			float4 FloodProperties = lerp( Properties, FloodPropertiesSettings, FloodBlendFactors.y * FloodWaterPropertiesBlend );
			WaterNormalLerp = FloodBlendFactors.y;
			WaterNormalLerp = smoothstep( 0.8f, 1.0f, WaterNormalLerp );

			// Apply Flood
			FloodDiffuse.rgb = lerp( FloodDiffuse.rgb, FloodDiffuse.rgb * FloodDiffuseWetMultiplier, ConditionValue );
			FloodProperties.a = lerp( FloodProperties.a, FloodProperties.a * FloodPropertiesWetMultiplier, ConditionValue );

			Diffuse = lerp( Diffuse, FloodDiffuse, ConditionValue );
			Normal = lerp( Normal, FloodNormal, ConditionValue );
			Properties = lerp( Properties, FloodProperties, ConditionValue );
		}

		void ApplySummerDiffuseTerrain( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float2 WorldSpacePosXz, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float2 MapCoords = WorldSpacePosXz * WorldSpaceToTerrain0To1;
			float2 DetailUV = CalcDetailUV( WorldSpacePosXz );

			float4 SummerDiffuse = Diffuse;
			float3 SummerNormal = Normal;
			float4 SummerProperties = Properties;

			float SlopeMultiplier = dot( CalculateNormal( WorldSpacePosXz ), UP_VECTOR );
			SlopeMultiplier = RemapClamped( SlopeMultiplier, SummerSlopeMin, 1.0f, 0.0f, 1.0f );
			ConditionValue *= SlopeMultiplier;

			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float GrassPositionValue = lerp( SummerGrassMaskPositionFrom, SummerGrassMaskPositionTo, ConditionValue );
			float GrassContrastValue = lerp( SummerGrassMaskContrastFrom, SummerGrassMaskContrastTo, ConditionValue );

			// Grass patches
			float4 GrassTexDiffuse = PdxTex2D( DetailTextures, float3( DetailUV, SummerGrassTexureIndex ) );
			GrassTexDiffuse.a = 1.0f - GrassTexDiffuse.r;
			float4 GrassTexNormalRRxG = PdxTex2D( NormalTextures, float3( DetailUV, SummerGrassTexureIndex ) );
			float3 GrassTexNormal = UnpackRRxGNormal( GrassTexNormalRRxG ).xyz;
			float4 GrassTexProperties = PdxTex2D( MaterialTextures, float3( DetailUV, SummerGrassTexureIndex ) );

			float2 GrassMaskUV = float2( MapCoords.x * 2.0f, MapCoords.y ) * SummerGrassMaskUVTiling;
			float GrassNoiseMask = PdxTex2D( ProvinceEffectsNoise, GrassMaskUV ).r;

			float GrassMask = LevelsScan( GrassNoiseMask, GrassPositionValue, GrassContrastValue ) * SummerGrassTextureBlendWeight * SummerBlendWeight;
			float2 GrassBlendFactors = CalcHeightBlendFactors( float2( Diffuse.a, GrassTexDiffuse.a ), float2( 1.0f - GrassMask, GrassMask ), DetailBlendRange );

			// Apply grass color
			GrassTexDiffuse.rgb = Overlay( GrassTexDiffuse.rgb, SummerGrassOverlayColor );
			SummerDiffuse.rgb = lerp( SummerDiffuse.rgb, GrassTexDiffuse.rgb, GrassBlendFactors.y );
			SummerNormal = lerp( SummerNormal, GrassTexNormal, GrassBlendFactors.y );
			SummerProperties = lerp( SummerProperties, GrassTexProperties, GrassBlendFactors.y );
			Diffuse.rgb = lerp( Diffuse.rgb, SummerDiffuse.rgb, ConditionValue );
			Normal = lerp( Normal, SummerNormal, ConditionValue );
			Properties = lerp( Properties, SummerProperties, ConditionValue );
		}

		void ApplyProvinceEffectsTerrain( in EffectIntensities ConditionData, inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float3 WorldSpacePos, inout float WaterNormalLerp )
		{
			ApplyDroughtDiffuseTerrain( Diffuse, Normal, Properties, WorldSpacePos.xz, ConditionData._Drought );
			ApplyFloodingDiffuseTerrain( Diffuse, Normal, Properties, WorldSpacePos.xz, ConditionData._Flood, WaterNormalLerp );
			ApplySummerDiffuseTerrain( Diffuse, Normal, Properties, WorldSpacePos.xz, ConditionData._Summer );

			DebugCondition( Diffuse.rgb, ConditionData );
		}

		void ApplyDroughtDiffuseTree( inout float4 Diffuse, float2 WorldSpacePosXz, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float SlopeMultiplier = dot( CalculateNormal( WorldSpacePosXz ), UP_VECTOR );
			SlopeMultiplier = RemapClamped( SlopeMultiplier, DroughtSlopeMin, 1.0f, 0.0f, 1.0f );

			ConditionValue *= SlopeMultiplier;

			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float3 DroughtDiffuse = AdjustHsv( Diffuse.rgb, 0.0f, DroughtPreSaturation, DroughtPreValue );
			DroughtDiffuse = Overlay( DroughtDiffuse, DroughtOverlayTree );
			Diffuse.rgb = lerp( Diffuse.rgb, DroughtDiffuse, ConditionValue );
			Diffuse.a = lerp( Diffuse.a, smoothstep( 0.0f, 2.0f, Diffuse.a ), ConditionValue );
		}

		void ApplySummerDiffuseTree( inout float4 Diffuse, float2 WorldSpacePosXz, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float SlopeMultiplier = dot( CalculateNormal( WorldSpacePosXz ), UP_VECTOR );
			SlopeMultiplier = RemapClamped( SlopeMultiplier, SummerSlopeMin, 1.0f, 0.0f, 1.0f );

			ConditionValue = ConditionValue * SlopeMultiplier * SummerBlendWeight;

			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float3 SummerDiffuse = Overlay( Diffuse.rgb, SummerOverlayTree );
			Diffuse.rgb = lerp( Diffuse.rgb, SummerDiffuse, ConditionValue );
		}

		void ApplySnowDiffuseTree( inout float4 Diffuse, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			Diffuse.a = lerp( Diffuse.a, smoothstep( 0.0f, 1.5f, Diffuse.a ), ConditionValue );
		}

		void ApplyProvinceEffectsTree( in EffectIntensities ConditionData, inout float4 Diffuse, float2 MapCoords, float2 WorldSpacePosXz )
		{
			ApplyDroughtDiffuseTree( Diffuse, WorldSpacePosXz, ConditionData._Drought );
			ApplySummerDiffuseTree( Diffuse, WorldSpacePosXz, ConditionData._Summer );
			ApplySnowDiffuseTree( Diffuse, ConditionData._Snow );
			DebugCondition( Diffuse.rgb, ConditionData );
		}

		void ApplyDroughtDiffuseDecal( inout float3 Diffuse, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float3 DroughtDiffuse = Diffuse;
			DroughtDiffuse = AdjustHsv( DroughtDiffuse, 0.0f, DroughtDecalPreSaturation, DroughtDecalPreValue );
			DroughtDiffuse = Overlay( DroughtDiffuse, DroughtOverlayDecal );
			DroughtDiffuse = AdjustHsv( DroughtDiffuse, 0.0f, DroughtDecalFinalSaturation, 1.0f );
			Diffuse.rgb = lerp( Diffuse.rgb, DroughtDiffuse, ConditionValue );
		}

		void ApplyProvinceEffectsDecal( in EffectIntensities ConditionData, inout float3 Diffuse, float2 MapCoords )
		{
			ApplyDroughtDiffuseDecal( Diffuse, ConditionData._Drought );

			DebugCondition( Diffuse.rgb, ConditionData );
		}
	]]
}
