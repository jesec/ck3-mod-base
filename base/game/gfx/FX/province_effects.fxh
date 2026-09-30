Includes = {
	"cw/pdxterrain.fxh"
	"jomini/jomini_province_overlays.fxh"
	"province_effects_variables.fxh"
	"disease.fxh"
	"standardfuncsgfx.fxh"
}

struct EffectIntensities
{
	float _Drought;
	float _Flood;
	float _Summer;
	float _Snow;
	float _DivergentRites;
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
		// #define DEBUG_PROVINCE_EFFECT_MASK_DIVERGENT_RITES

		static const float3 UP_VECTOR = float3( 0.0f, 1.0f, 0.0f );
		static const float SKIP_VALUE = 0.001f;

		void DebugCondition( inout float3 Diffuse, EffectIntensities ConditionData )
		{
			#if defined( DEBUG_PROVINCE_EFFECT_MASK_DROUGHT )
				Diffuse.rgb = lerp( Diffuse.rgb, float3( 1.0f, 0.0f, 0.0f ), ConditionData._Drought );
			#endif

			#if defined( DEBUG_PROVINCE_EFFECT_MASK_FLOOD )
				Diffuse.rgb = lerp( Diffuse.rgb, float3( 0.0f, 1.0f, 0.0f ), ConditionData._Flood );
			#endif

			#if defined( DEBUG_PROVINCE_EFFECT_MASK_SUMMER )
				Diffuse.rgb = lerp( Diffuse.rgb, float3( 0.0f, 0.0f, 1.0f ), ConditionData._Summer );
			#endif

			#if defined( DEBUG_PROVINCE_EFFECT_MASK_SNOW )
				Diffuse.rgb = lerp( Diffuse.rgb, float3( 1.0f, 1.0f, 0.0f ), ConditionData._Snow );
			#endif

			#if defined( DEBUG_PROVINCE_EFFECT_MASK_DIVERGENT_RITES )
				Diffuse.rgb = lerp( Diffuse.rgb, float3( 0.0f, 1.0f, 1.0f ), ConditionData._DivergentRites );
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

		float CalculateStripeMaskCustom( in float2 UV, float Offset, float Angle, float StripeWidthScale )
		{
			float NoStripe = step( 1.0f, StripeWidthScale );
			float FullStripe = step( StripeWidthScale, -1.0f );
			float AiagonalAngle = 3.14159f / Angle;
			float StripeFreq = 3000;
			float StripePattern = UV.x * cos( AiagonalAngle ) * StripeFreq + UV.y * sin( AiagonalAngle ) * StripeFreq;
			float StripeMask = cos( StripePattern + Offset ) - StripeWidthScale;
			float Width = max( fwidth( StripePattern ), 0.0001f );
			StripeMask = smoothstep( -Width, Width, StripeMask );
			return lerp( lerp( StripeMask, 0.0f, NoStripe ), 1.0f, FullStripe );
		}

		void ApplyDiagonalStripesCustom( inout float4 BaseColor, float4 StripeColor, float ShadowAmount, float2 WorldSpacePosXZ, float Angle, float LineWidthFactor )
		{
			float Mask = CalculateStripeMaskCustom( WorldSpacePosXZ, 0.0f, Angle, LineWidthFactor );
			float OffsetMask = CalculateStripeMaskCustom( WorldSpacePosXZ, -0.5f, Angle, LineWidthFactor );
			float Shadow = 1.0f - saturate( Mask - OffsetMask );
			Mask *= StripeColor.a;
			BaseColor.rgb = lerp( BaseColor.rgb, BaseColor.rgb * Shadow, Mask * ShadowAmount );
			BaseColor = lerp( BaseColor, StripeColor, Mask );
		}

		float CalculateZigZagStripeMaskCustom( in float2 UV, float Offset, float Angle, float StripeWidthScale, float ZigZagFreq, float ZigZagAmplitude )
		{
			float NoStripe = step( 1.0f, StripeWidthScale );
			float FullStripe = step( StripeWidthScale, -1.0f );
			float DiagonalAngle = Angle;
			float StripeFreq = 3500.0f;
			float Along = UV.x * cos( DiagonalAngle ) + UV.y * sin( DiagonalAngle );
			float Ortho = -UV.x * sin( DiagonalAngle ) + UV.y * cos( DiagonalAngle );
			float TriangleWave = abs( frac( Ortho * ZigZagFreq ) - 0.5f ) * 2.0f - 0.5f;
			float StripePattern = ( Along + ZigZagAmplitude * TriangleWave ) * StripeFreq;
			float StripeMask = cos( StripePattern + Offset ) - StripeWidthScale;
			float Width = max( fwidth( StripePattern ), 0.0001f );
			StripeMask = smoothstep( -Width, Width, StripeMask );
			return lerp( lerp( StripeMask, 0.0f, NoStripe ), 1.0f, FullStripe );
		}

		void ApplyZigZagStripesCustom( inout float4 BaseColor, float4 StripeColor, float ShadowAmount, float2 WorldSpacePosXZ, float Angle, float LineWidthFactor, float ZigZagFreq, float ZigZagAmplitude )
		{
			float Mask = CalculateZigZagStripeMaskCustom( WorldSpacePosXZ, 0.0f, Angle, LineWidthFactor, ZigZagFreq, ZigZagAmplitude );
			Mask *= StripeColor.a;
			BaseColor = lerp( BaseColor, StripeColor, Mask );
		}

		float CheckSkipBorderColor( float ConditionValue )
		{
			float Cond1 = step( 0.00001f, ConditionValue );
			float Cond2 = step( _StartColorOverlayHeightBlend, 0.00001f );
			return 1.0f - Cond1 * Cond2;
		}

		float4 SampleProvinceEffects( float2 MapCoords )
		{
			float2 ColorIndex = PdxTex2D( ProvinceColorIndirectionTexture, MapCoords ).rg;
			int Index = ColorIndex.x * 255.0f + ColorIndex.y * 255.0f * 256.0f;
			return PdxReadBuffer4( ProvinceEffectDataBuffer, Index );
		}

		float BilinearConditionWeight( float4 C11, float4 C21, float4 C12, float4 C22, float2 FracCoord, float Impact, int ConditionIndex)
		{
			float v1 = lerp( C11.r == ConditionIndex, C21.r == ConditionIndex, FracCoord.x );
			float v2 = lerp( C12.r == ConditionIndex, C22.r == ConditionIndex, FracCoord.x );
			return lerp( v1, v2, FracCoord.y ) * Impact;
		}

		void BilinearSampleProvinceEffectsMask( float2 MapCoords, inout EffectIntensities ConditionData )
		{
			#ifdef LOW_SPEC_SHADERS
				ConditionData._Drought = 0.0f;
				ConditionData._Flood = 0.0f;
				ConditionData._Summer = 0.0f;
				ConditionData._Snow = 0.0f;
				ConditionData._DivergentRites = 0.0f;
				return;
			#endif

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
			float ImpactTemp = lerp( x1, x2, FracCoord.y );
			float Impact = RemapClamped( ImpactTemp, 0.0f, OpacityLowImpactValue, 0.0f, 0.5f );
			Impact += RemapClamped( ImpactTemp, OpacityLowImpactValue, OpacityHighImpactValue, 0.0f, 0.5f );

			ConditionData._Drought = BilinearConditionWeight( C11, C21, C12, C22, FracCoord, Impact, DROUGHT_INDEX );
			ConditionData._Flood = BilinearConditionWeight( C11, C21, C12, C22, FracCoord, Impact, FLOOD_INDEX );
			ConditionData._Summer = BilinearConditionWeight( C11, C21, C12, C22, FracCoord, Impact, SUMMER_INDEX );
			ConditionData._Snow = BilinearConditionWeight( C11, C21, C12, C22, FracCoord, Impact, SNOW_INDEX );
			ConditionData._DivergentRites = BilinearConditionWeight( C11, C21, C12, C22, FracCoord, ImpactTemp, DIVERGENT_RITES_INDEX );
		}
		
		void SampleProvinceEffectsMask( float2 MapCoords, inout EffectIntensities ConditionData )
		{
			#ifdef LOW_SPEC_SHADERS
				ConditionData._Drought = 0.0f;
				ConditionData._Flood = 0.0f;
				ConditionData._Summer = 0.0f;
				ConditionData._Snow = 0.0f;
				ConditionData._DivergentRites = 0.0f;
				return;
			#endif

			float2 Pixel = MapCoords * IndirectionMapSize + 0.5f;
			Pixel = floor( Pixel ) / IndirectionMapSize - InvIndirectionMapSize / 2.0f;
			float4 Sample = SampleProvinceEffects( Pixel );

			float ImpactTemp = Sample.g;

			float Impact = RemapClamped( ImpactTemp, 0.0f, OpacityLowImpactValue, 0.0f, 0.5f );
			Impact += RemapClamped( ImpactTemp, OpacityLowImpactValue, OpacityHighImpactValue, 0.0f, 0.5f );

			ConditionData._Drought = ( Sample.r == DROUGHT_INDEX ) * Impact;
			ConditionData._Flood = ( Sample.r == FLOOD_INDEX ) * Impact;
			ConditionData._Summer = ( Sample.r == SUMMER_INDEX ) * Impact;
			ConditionData._Snow = ( Sample.r == SNOW_INDEX ) * Impact;
			ConditionData._DivergentRites = ( Sample.r == DIVERGENT_RITES_INDEX ) * ImpactTemp;
		}

		float SampleProvinceDivergentRitesEffectMask( float2 MapCoords )
		{
			float2 Pixel = MapCoords * IndirectionMapSize + 0.5f;
			Pixel = floor( Pixel ) / IndirectionMapSize - InvIndirectionMapSize / 2.0f;
			float4 Sample = SampleProvinceEffects( Pixel );

			float ImpactTemp = Sample.g;

			float Impact = RemapClamped( ImpactTemp, 0.0f, OpacityLowImpactValue, 0.0f, 0.5f );
			Impact += RemapClamped( ImpactTemp, OpacityLowImpactValue, OpacityHighImpactValue, 0.0f, 0.5f );
			return ( Sample.r == DIVERGENT_RITES_INDEX ) * ImpactTemp;
		}

		void ApplyDroughtDiffuseTerrain( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float3 TerrainNormal, float2 MapCoords, float2 WorldSpacePosXz, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float SlopeMultiplier = dot( TerrainNormal, UP_VECTOR );
			SlopeMultiplier = RemapClamped( SlopeMultiplier, DroughtSlopeMin, 1.0f, 0.0f, 1.0f );
			ConditionValue *= SlopeMultiplier;

			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float2 DetailUV = CalcDetailUV( WorldSpacePosXz );

			float4 DroughtDiffuse = Diffuse;
			float3 DroughtNormal = Normal;
			float4 DroughtProperties = Properties;

			float ColorPositionValue = lerp( DroughtColorMaskPositionFrom, DroughtColorMaskPositionTo, ConditionValue );
			float ColorContrastValue = lerp( DroughtColorMaskContrastFrom, DroughtColorMaskContrastTo, ConditionValue );
			float DryPositionValue = lerp( DroughtDryMaskPositionFrom, DroughtDryMaskPositionTo, ConditionValue );
			float DryContrastValue = lerp( DroughtDryMaskContrastFrom, DroughtDryMaskContrastTo, ConditionValue );
			float CracksPositionValue = lerp( DroughtCracksAreaMaskPositionFrom, DroughtCracksAreaMaskPositionTo, ConditionValue );
			float CracksContrastValue = lerp( DroughtCracksAreaMaskContrastFrom, DroughtCracksAreaMaskContrastTo, ConditionValue );

			// Dry patches
			float4 DryTexDiffuse = PdxTex2D( DetailTextures, float3( DetailUV, DroughtDryTexureIndex ) );
			DryTexDiffuse.a = 1.0f - DryTexDiffuse.r;
			float4 DryTexNormalRRxG = PdxTex2D( NormalTextures, float3( DetailUV, DroughtDryTexureIndex ) );
			float3 DryTexNormal = UnpackRRxGNormal( DryTexNormalRRxG ).xyz;
			float4 DryTexProperties = PdxTex2D( MaterialTextures, float3( DetailUV, DroughtDryTexureIndex ) );

			float2 DryMaskUV = float2( MapCoords.x * 2.0f, MapCoords.y ) * DroughtDryMaskUVTiling;
			float DryNoiseMask = PdxTex2D( ProvinceEffectsNoise, DryMaskUV ).r;

			float DryMask = LevelsScan( DryNoiseMask, DryPositionValue, DryContrastValue ) * DroughtDryTextureBlendWeight * DroughtBlendWeight;
			float2 DryBlendFactors = CalcHeightBlendFactors( float2( Diffuse.a, DryTexDiffuse.a ), float2( 1.0f - DryMask, DryMask ), DetailBlendRange * DroughtDryTextureBlendContrast);

			// Base terrain color change
			float ColorNoise = LevelsScan( DryNoiseMask, ColorPositionValue, ColorContrastValue );
			DroughtDiffuse.rgb = lerp( DroughtDiffuse.rgb, AdjustHsv( DroughtDiffuse.rgb, 0.0f, DroughtPreSaturation, DroughtPreValue ), ColorNoise );
			DroughtDiffuse.rgb = lerp( DroughtDiffuse.rgb, Overlay( DroughtDiffuse.rgb, DroughtOverlayColor ), ColorNoise );

			DryTexDiffuse.rgb = Overlay( DryTexDiffuse.rgb, DroughtDryOverlayColor );
			DroughtDiffuse.rgb = lerp( DroughtDiffuse.rgb, DryTexDiffuse.rgb, DryBlendFactors.y );
			DroughtNormal = lerp( DroughtNormal, DryTexNormal, DryBlendFactors.y );
			DroughtProperties = lerp( DroughtProperties, DryTexProperties, DryBlendFactors.y );

			float DroughtWaterMask = smoothstep( 0.0f, 0.104f, ( 1.0f - DroughtProperties.a ) * DryMask );
			if ( DroughtWaterMask > 0.0001f )
			{
				DroughtDiffuse.rgb = lerp( DroughtDiffuse.rgb, DryTexDiffuse.rgb, DroughtWaterMask * 0.1f );
				DroughtProperties.a = lerp( DroughtProperties.a , DryTexProperties.a , DroughtWaterMask );
				DroughtNormal = lerp( DroughtNormal , DryTexNormal , DroughtWaterMask * 0.5f );
			}

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

		void ApplyFloodingDiffuseTerrain( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float3 TerrainNormal, float2 MapCoords, float2 WorldSpacePosXz, float ConditionValue, inout float WaterNormalLerp )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}
			ConditionValue *= 0.95f;

			float2 TextureUV = MapCoords * float2( 2.0f, 1.0f );
			float2 DetailUV = CalcDetailUV( WorldSpacePosXz ) * FloodDetailTiling;

			float AdjustedPositionValue = lerp( FloodNoisePositionFrom, FloodNoisePositionTo, ConditionValue );
			float AdjustedContrastValue = lerp( FloodNoiseContrastFrom, FloodNoiseContrastTo, ConditionValue );

			float SlopeMultiplier = dot( TerrainNormal, UP_VECTOR );
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

		void ApplySummerDiffuseTerrain( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float3 TerrainNormal, float2 MapCoords, float2 WorldSpacePosXz, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float SlopeMultiplier = dot( TerrainNormal, UP_VECTOR );
			SlopeMultiplier = RemapClamped( SlopeMultiplier, SummerSlopeMin, 1.0f, 0.0f, 1.0f );
			ConditionValue *= SlopeMultiplier;

			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float2 DetailUV = CalcDetailUV( WorldSpacePosXz );

			float4 SummerDiffuse = Diffuse;
			float3 SummerNormal = Normal;
			float4 SummerProperties = Properties;

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

		void ApplyBurningArroundBorderDiffuseTerrain( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float3 TerrainNormal, float2 MapCoords, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float SlopeMultiplier = dot( TerrainNormal, UP_VECTOR );
			SlopeMultiplier = RemapClamped( SlopeMultiplier, BurningSlopeMin, 1.0f, 0.0f, 1.0f );
			ConditionValue *= SlopeMultiplier;

			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			// Bright terrain (e.g. desert) darken factor: avoid burnt zone looking too bright
			float OriginalLuminance = dot( Diffuse.rgb, LuminanceDotValue );
			float BrightTerrainDarken = lerp( 1.0f, 0.12f, saturate( ( OriginalLuminance - 0.226f ) * 4.9f ) );//0.38

			// Hell-like base tint
			const float3 HellOverlay = float3( 0.55f, 0.12f, 0.04f );
			float3 HellBase = Overlay( Diffuse.rgb, HellOverlay );
			Diffuse.rgb = lerp( Diffuse.rgb, HellBase, ConditionValue * 0.5f );

			// UV and Coordinate Setup
			float2 BuringMaskUV = float2( MapCoords.x * 2.0f, MapCoords.y );

			// Base Noise Sampling 
			float4 NoiseMask = SampleNoTile( ProvinceEffectsNoise, BuringMaskUV * BurningNoiseUVTiling + ( Normal.xy - 0.5f ) * 0.03f );
			// Fire Color Definitions 
			float3 CharredDiffuse = ( OriginalLuminance.xxx + Diffuse.rgb ) * 0.25f;
			const float3 FireLow = float3( 1.0f, 0.3f, 0.01f );
			const float3 FireMid = float3( 1.0f, 0.3f, 0.05f );
			const float3 FireHot = float3( 1.0f, 0.5f, 0.3f );
			// Moving Noise for Dynamic Effects 
			const float2 PanSpeed = float2( 0.0055f, 0.0015f );
			float2 UVPan = frac( GlobalTime * PanSpeed ) * float2( -1.0f, 1.0f );

			float4 MovingNoise = PdxTex2D( ProvinceEffectsNoise, BuringMaskUV * 15.0f + UVPan );

			// Base Burn Mask Calculation 
			float Noise = NoiseMask.a;
			float BurnPosition = lerp( 1.0f, 0.40f, ConditionValue );
			float BurnMask = smoothstep( BurnPosition - BurningEdgeWidth, BurnPosition, Noise );

			// Dynamic Fire Edge Effects 
			const float SlowNoiseStrength = 0.04f;
			const float SlowAnimSpeed = 2.0f;
			const float SlowAnimStrength = 0.148f;
			const float FastNoiseStrength = 0.015f;
			float FastAnimSpeed = 15.0f;
			const float FastAnimStrength = 0.08f;
			const float MinEdgeWidth = 0.001f;

			FastAnimSpeed = GlobalTime * FastAnimSpeed;
			FastAnimSpeed = sin( FastAnimSpeed ) + 0.5f * sin( FastAnimSpeed * 1.3f );

			float4 MidMovingNoise = MovingNoise - 0.5f;
			
			float SlowNoise = MidMovingNoise.g * ( SlowNoiseStrength + sin( GlobalTime * SlowAnimSpeed ) * SlowAnimStrength );
			float FastNoise = MidMovingNoise.r * ( FastNoiseStrength + FastAnimSpeed * FastAnimStrength );
			float DynamicEdgeWidth = max( BurningEdgeWidth + SlowNoise + FastNoise, MinEdgeWidth );
			
			float Jitter = MidMovingNoise.b * DynamicEdgeWidth;
			float StartPos = BurnPosition + Jitter;

			float BurnEdgeNoise = ( Noise - StartPos ) / ( DynamicEdgeWidth * 2.0f );
			BurnEdgeNoise = saturate( BurnEdgeNoise );
			float BurnEdge = 1.0f - abs( BurnEdgeNoise * 2.0f - 1.0f );
			BurnEdge = BurnEdge * BurnEdge * MovingNoise.r * 2.0f;

			// Enhanced Terrain Interaction
			float TerrainRoughness = saturate( Properties.a * 2.0f - 1.0f );
			float TerrainHeight = Diffuse.a;
			float TerrainSlopeInfluence = saturate( dot( Normal.xy, Normal.xy ) * 2.0f );

			// Fire spreads differently based on terrain properties
			float TerrainFireAffinity = 0.5f + TerrainRoughness;
			float SlopeFireSpeed = 1.0f - TerrainSlopeInfluence * 0.7f;
			
			// Apply terrain influence to burn edge
			float EnhancedBurnEdge = saturate( BurnEdge * TerrainFireAffinity * SlopeFireSpeed );

			// Height-Based Blending
			const float BlendRangeMultiplier = 4.0f;
			const float RoughnessBlendMin = 0.5f;
			const float RoughnessBlendMax = 2.0f;
			
			float2 FireBlendFactors = CalcHeightBlendFactors(
				float2( 1.0f - TerrainHeight, EnhancedBurnEdge ),
				float2( 1.0f - EnhancedBurnEdge, EnhancedBurnEdge ),
				DetailBlendRange * BlendRangeMultiplier * lerp( RoughnessBlendMin, RoughnessBlendMax, TerrainRoughness ) 
			);

			// Terrain-Influenced Fire Colors
			const float FireColorDimFactor = 0.8f;
			const float FireColorHotFactor = 1.2f;
			const float TerrainTintStrength = 0.1f;
			
			float3 TerrainInfluencedFireLow = lerp( FireLow, FireLow * FireColorDimFactor, TerrainRoughness );
			float3 TerrainInfluencedFireHot = lerp( FireHot, FireHot * FireColorHotFactor, TerrainRoughness );
			
			// Add subtle terrain color influence
			float3 TerrainTint = Diffuse.rgb * TerrainTintStrength;
			TerrainInfluencedFireLow += TerrainTint;

			// Final Fire Color Calculation
			float3 FireColor = lerp( TerrainInfluencedFireLow, FireMid, EnhancedBurnEdge );
			FireColor = lerp( FireColor, TerrainInfluencedFireHot, EnhancedBurnEdge * EnhancedBurnEdge );
			// Enhanced Charred Effect
			const float CharredRoughnessFactor = 0.4f;
			const float CharredSlopeTintStrength = 0.2f;
			const float CharredSlopeFactor = 0.3f;
			
			float3 EnhancedCharredDiffuse = lerp( CharredDiffuse, CharredDiffuse * CharredRoughnessFactor, TerrainRoughness );
			EnhancedCharredDiffuse = lerp( EnhancedCharredDiffuse, Diffuse.rgb * CharredSlopeTintStrength, TerrainSlopeInfluence * CharredSlopeFactor );
			EnhancedCharredDiffuse *= BrightTerrainDarken;

			// Apply Effects to Diffuse
			Diffuse.rgb = lerp( Diffuse.rgb, EnhancedCharredDiffuse, BurnMask );
			Diffuse.rgb = lerp( Diffuse.rgb, FireColor, FireBlendFactors.y );

			// Dynamic Embers/Sparks Effect
			float EmberEffect = TerrainRoughness * EnhancedBurnEdge * sin( GlobalTime * 10.0f + TerrainHeight * 20.0f ) * 0.2f;
			Diffuse.rgb += FireLow * max( 0.0f, EmberEffect );
		}

		void ApplyBurningDiffuseTerrain( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float3 TerrainNormal, float2 MapCoords, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}
			ConditionValue = pow( ConditionValue, 0.3f );
			float SlopeMultiplier = dot( TerrainNormal, UP_VECTOR );
			SlopeMultiplier = RemapClamped( SlopeMultiplier, BurningSlopeMin, 1.0f, 0.0f, 1.0f );
			ConditionValue *= SlopeMultiplier;
			
			float ZoomFadeFactor = 1.0 - smoothstep( 350, 390, CameraPosition.y );
			ConditionValue *= ZoomFadeFactor;
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			const float DistanceFieldValue = CalcDistanceFieldValue( MapCoords );
			const float MainAreaMask = smoothstep( 0.026f, 0.062, DistanceFieldValue );
			float EdgeMask = smoothstep( 0.025f, 0.101f, DistanceFieldValue ) * ( 1 - smoothstep(-0.057f, 0.162f, DistanceFieldValue ) ) * 5.0f;
			EdgeMask *= EdgeMask;
			// Bright terrain (e.g. desert) darken factor: avoid burnt zone looking too bright
			float OriginalLuminance = dot( Diffuse.rgb, LuminanceDotValue );
			float BrightTerrainDarken = lerp( 1.0f, 0.12f, saturate( ( OriginalLuminance - 0.226f ) * 4.9f ) );//0.38


			const float2 BuringMaskUV = float2( MapCoords.x * 2.0f, MapCoords.y );
			const float4 NoiseMask = SampleNoTile( ProvinceEffectsNoise, BuringMaskUV * BurningNoiseUVTiling + ( Normal.xy - 0.5f ) * 0.03f );

			// Base Burn Mask Calculation 
			const float Noise = NoiseMask.a;
			float BurnPosition = lerp( 1.0f, 0.40f, ConditionValue );
			const float BurnMask = smoothstep( BurnPosition - BurningEdgeWidth, BurnPosition, Noise );

			// Enhanced Terrain Interaction
			const float TerrainRoughness = saturate( Properties.a * 2.0f - 1.0f );
			const float TerrainHeight = Diffuse.a;
			const float TerrainSlopeInfluence = saturate( dot( Normal.xy, Normal.xy ) * 2.0f );

			// Enhanced Charred Effect
			const float CharredRoughnessFactor = 0.4f;
			const float CharredSlopeTintStrength = 0.2f;
			const float CharredSlopeFactor = 0.3f;
			const float3 CharredDiffuse = ( OriginalLuminance.xxx + Diffuse.rgb ) * 0.25f;
			float3 EnhancedCharredDiffuse = lerp( CharredDiffuse, CharredDiffuse * CharredRoughnessFactor, TerrainRoughness );
			EnhancedCharredDiffuse = lerp( EnhancedCharredDiffuse, Diffuse.rgb * CharredSlopeTintStrength, TerrainSlopeInfluence * CharredSlopeFactor );
			EnhancedCharredDiffuse *= BrightTerrainDarken;

			// Apply Effects to Diffuse
			Diffuse.rgb = lerp( Diffuse.rgb, EnhancedCharredDiffuse, BurnMask * MainAreaMask );

			// Hell-like base tint
			const float3 HellOverlay = float3( 1.0f, 0.12f, 0.04f );
			const float3 HellBase = Overlay( Diffuse.rgb, HellOverlay );
			Diffuse.rgb = lerp( Diffuse.rgb, HellBase, ConditionValue * MainAreaMask);

			float Luminance = dot( Diffuse.rgb, LuminanceDotValue );
			Diffuse.rgb = lerp( Diffuse.rgb, Luminance, 0.6f * ConditionValue * MainAreaMask);

			if ( EdgeMask > SKIP_VALUE )
			{
				const float3 FireLow = float3( 1.0f, 0.3f, 0.01f );
				const float3 FireMid = float3( 1.0f, 0.3f, 0.05f );
				const float3 FireHot = float3( 1.0f, 0.5f, 0.3f );
				// Fire spreads differently based on terrain properties
				const float TerrainFireAffinity = 0.5f + TerrainRoughness;
				const float SlopeFireSpeed = 1.0f - TerrainSlopeInfluence * 0.7f;

				// Dynamic Fire Edge Effects 
				const float SlowNoiseStrength = 0.04f;
				const float SlowAnimSpeed = 2.0f;
				const float SlowAnimStrength = 0.148f;
				const float FastNoiseStrength = 0.015f;
				float FastAnimSpeed = 15.0f;
				const float FastAnimStrength = 0.08f;
				const float MinEdgeWidth = 0.001f;

				// Moving Noise for Dynamic Effects 
				const float2 PanSpeed = float2( 0.0055f, 0.0015f );
				const float2 UVPan = frac( GlobalTime * PanSpeed ) * float2( -1.0f, 1.0f );
				const float4 MovingNoise = PdxTex2D( ProvinceEffectsNoise, BuringMaskUV * 15.0f + UVPan );
				const float4 MidMovingNoise = MovingNoise - 0.5f;

				FastAnimSpeed = GlobalTime * FastAnimSpeed;
				FastAnimSpeed = sin( FastAnimSpeed ) + 0.5f * sin( FastAnimSpeed * 1.3f );

				const float SlowNoise = MidMovingNoise.g * ( SlowNoiseStrength + sin( GlobalTime * SlowAnimSpeed ) * SlowAnimStrength );
				const float FastNoise = MidMovingNoise.r * ( FastNoiseStrength + FastAnimSpeed * FastAnimStrength );
				const float DynamicEdgeWidth = max( BurningEdgeWidth + SlowNoise + FastNoise, MinEdgeWidth );

				const float Jitter = MidMovingNoise.a * DynamicEdgeWidth;
				const float StartPos = lerp( 1.0f, 0.40f, ConditionValue * 1.2f ) + Jitter;

				float BurnEdgeNoise = ( Noise - StartPos ) / ( DynamicEdgeWidth * 2.0f );
				BurnEdgeNoise = saturate( BurnEdgeNoise );
				float BurnEdge = 1.0f - abs( BurnEdgeNoise * 2.0f - 1.0f );
				BurnEdge = BurnEdge * BurnEdge * MovingNoise.r * 2.0f;

				// Apply terrain influence to burn edge
				float EnhancedBurnEdge = saturate( BurnEdge * TerrainFireAffinity * SlopeFireSpeed );

				// Height-Based Blending
				const float BlendRangeMultiplier = 4.0f;
				const float RoughnessBlendMin = 0.5f;
				const float RoughnessBlendMax = 2.0f;
				
				float2 FireBlendFactors = CalcHeightBlendFactors(
					float2( 1.0f - TerrainHeight, EnhancedBurnEdge ),
					float2( 1.0f - EnhancedBurnEdge, EnhancedBurnEdge ),
					DetailBlendRange * BlendRangeMultiplier * lerp( RoughnessBlendMin, RoughnessBlendMax, TerrainRoughness ) 
				);

				// Terrain-Influenced Fire Colors
				const float FireColorDimFactor = 0.8f;
				const float FireColorHotFactor = 1.2f;
				const float TerrainTintStrength = 0.5f;
				float3 TerrainInfluencedFireLow = lerp( FireLow, FireLow * FireColorDimFactor, TerrainRoughness );
				float3 TerrainInfluencedFireHot = lerp( FireHot, FireHot * FireColorHotFactor, TerrainRoughness );

				// Add subtle terrain color influence
				const float3 TerrainTint = Diffuse.rgb * TerrainTintStrength;
				const float3 TerrainInfluencedFireLowWithTint = TerrainInfluencedFireLow + TerrainTint;
				// Final Fire Color Calculation
				float3 FireColor = lerp( TerrainInfluencedFireLowWithTint, FireMid, EnhancedBurnEdge );
				FireColor = lerp( FireColor, TerrainInfluencedFireHot, EnhancedBurnEdge * EnhancedBurnEdge );
				Diffuse.rgb = lerp( Diffuse.rgb, FireColor, FireBlendFactors.y * EdgeMask );

				// Dynamic Embers/Sparks Effect
				float EmberEffect = TerrainRoughness * EnhancedBurnEdge * sin( GlobalTime * 10.0f + TerrainHeight * 20.0f ) * 0.2f;
				Diffuse.rgb += FireLow * max( 0.0f, EmberEffect * EdgeMask );
			}
		}

		void ApplyProvinceEffectsTerrain( in EffectIntensities ConditionData, inout float4 Diffuse, inout float3 Normal, inout float4 Properties, in float3 TerrainNormal, float3 WorldSpacePos, in float2 MapCoords, inout float WaterNormalLerp )
		{
			#ifdef LOW_SPEC_SHADERS
				return;
			#endif
			// Do not apply any effects to the snow.
			float3 SnowColor = float3( 0.698f, 0.737f, 0.765f );
			if ( !any( abs( Diffuse.rgb - SnowColor ) >= 0.45f ) )
			{
				return;
			}

			ApplyDroughtDiffuseTerrain( Diffuse, Normal, Properties, TerrainNormal, MapCoords, WorldSpacePos.xz, ConditionData._Drought );
			ApplyFloodingDiffuseTerrain( Diffuse, Normal, Properties, TerrainNormal, MapCoords, WorldSpacePos.xz, ConditionData._Flood, WaterNormalLerp );
			ApplySummerDiffuseTerrain( Diffuse, Normal, Properties, TerrainNormal, MapCoords, WorldSpacePos.xz, ConditionData._Summer );

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
			Diffuse.a = lerp( Diffuse.a, smoothstep( 0.8f, 0.85f, Diffuse.a ), ConditionValue );
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

			Diffuse.a = lerp( Diffuse.a, smoothstep( 0.8f, 0.85f, Diffuse.a ), ConditionValue );
		}

		void ApplyBurningTree( inout float4 Diffuse, float2 WorldSpacePosXz, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float2 MapCoords = WorldSpacePosXz * WorldSpaceToTerrain0To1;
			float2 BurningMaskUV = float2( MapCoords.x * 2.0f, MapCoords.y );
			float Noise = SampleNoTile( ProvinceEffectsNoise, BurningMaskUV * BurningNoiseUVTiling ).a;

			float BurnPosition = lerp( 1.0f, 0.40f, ConditionValue );
			float BlendWeight = ConditionValue * smoothstep( BurnPosition - BurningEdgeWidth, BurnPosition, Noise );
			float OriginalLuminance = dot( Diffuse.rgb, LuminanceDotValue );
			float3 CharredDiffuse = ( OriginalLuminance.xxx + Diffuse.rgb ) * 0.25f;
			CharredDiffuse = Overlay( CharredDiffuse, float3( 0.45f, 0.22f, 0.12f ) );
			Diffuse.rgb = lerp( Diffuse.rgb, CharredDiffuse, BlendWeight );
			Diffuse.rgb = lerp( Diffuse.rgb, dot( Diffuse.rgb, LuminanceDotValue ), BlendWeight );
			Diffuse.a = lerp( Diffuse.a, smoothstep( 0.8f, 0.85f, Diffuse.a ), BlendWeight );
		}

		void ApplyProvinceEffectsTree( in EffectIntensities ConditionData, inout float4 Diffuse, float2 MapCoords, float2 WorldSpacePosXz )
		{
			#ifdef LOW_SPEC_SHADERS
				return;
			#endif
			ApplyDroughtDiffuseTree( Diffuse, WorldSpacePosXz, ConditionData._Drought );
			ApplySummerDiffuseTree( Diffuse, WorldSpacePosXz, ConditionData._Summer );
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

		void ApplyBurningDecal( inout float3 Diffuse, float2 MapCoords, float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float2 BurningMaskUV = float2( MapCoords.x * 2.0f, MapCoords.y );
			float OriginalLuminance = dot( Diffuse.rgb, LuminanceDotValue );
			const float3 HellOverlay = float3( 0.55f, 0.12f, 0.04f );
			float3 HellBase = Overlay( Diffuse.rgb, HellOverlay );
			Diffuse.rgb = lerp( Diffuse.rgb, HellBase, ConditionValue * 0.5f );

			float Noise = SampleNoTile( ProvinceEffectsNoise, BurningMaskUV * BurningNoiseUVTiling ).a;
			float BurnPosition = lerp( 1.0f, 0.40f, ConditionValue );
			float BlendWeight = ConditionValue * smoothstep( BurnPosition - BurningEdgeWidth, BurnPosition, Noise );

			float3 CharredDiffuse = ( OriginalLuminance.xxx + Diffuse.rgb ) * 0.25f;
			Diffuse.rgb = lerp( Diffuse.rgb, CharredDiffuse, BlendWeight );
		}

		void ApplyDivergentRites( in float2 MapCoords, inout float3 Color, in float ConditionValue, in float IsFlatMap )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}

			float HereticThreshold = _RiteDivergenceHereticalThreshold;
			float ThresholdFactor = smoothstep( HereticThreshold, 1.0f, ConditionValue );
 
			ConditionValue -= 0.01f;
			float LineScale =  lerp( 0.3f, 0.70f, step( HereticThreshold, ConditionValue ) );
			float LineWidthFactor = 1.0f - ( ConditionValue * LineScale ) * 2.0f;
			float DistanceFieldValue = CalcDistanceFieldValue( MapCoords );
			DistanceFieldValue = pow( DistanceFieldValue, 0.15f );
			DistanceFieldValue = lerp( DistanceFieldValue, 1.0f, IsFlatMap );

			float2 Pixel = MapCoords * IndirectionMapSize + 0.5f;
			Pixel = floor( Pixel ) / IndirectionMapSize - InvIndirectionMapSize / 2.0f;
			float4 ProvinceOverlayColorWithAlpha = ColorSample( Pixel, ProvinceColorIndirectionTexture, ProvinceColorTexture );

			float4 ProvinceOverlaySecondColorWithAlpha = BilinearColorSampleAtOffset( MapCoords, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, SecondaryProvinceColorsOffset );
			ProvinceOverlayColorWithAlpha = lerp( ProvinceOverlayColorWithAlpha, ProvinceOverlaySecondColorWithAlpha, ProvinceOverlaySecondColorWithAlpha.a );

			float Luminance = dot( ProvinceOverlayColorWithAlpha.rgb, float3( 0.299f, 0.587f, 0.114f ) );
			float3 Gray = float3( Luminance, Luminance, Luminance );
			ProvinceOverlayColorWithAlpha.rgb = lerp( ProvinceOverlayColorWithAlpha.rgb, Gray, 0.1f );

			float3 PatternColor = float3( 0.202f, 0.195f, 0.174f );
			float3 OverlayColor = Overlay( PatternColor, ProvinceOverlayColorWithAlpha.rgb, 1.0f );
			ProvinceOverlayColorWithAlpha.rgb = lerp( ProvinceOverlayColorWithAlpha.rgb, OverlayColor, 1.0f - IsFlatMap * 0.5f );

			float StripeAnimationStrength = DivergentRitesAnimationStrength * step( HereticThreshold, ConditionValue + 0.01f );
			float StripeAnimation = sin( GlobalTime * DivergentRitesAnimationSpeed ) * 0.0001f * StripeAnimationStrength;
			float ZigZagFrequency = DivergentRitesZigZagFrequency;
			float ZigZagCurvature = lerp( 0.0f, DivergentRitesZigZagAmplitude, ThresholdFactor ) + StripeAnimation;
			float DarkenFactor = lerp( DivergentRitesColorScale, DivergentRitesColorScale * 0.5f, ThresholdFactor );
			DarkenFactor = lerp( DarkenFactor, 1.0f, ProvinceOverlaySecondColorWithAlpha.a );
			float4 StripeColor = float4( ProvinceOverlayColorWithAlpha.rgb * DarkenFactor, DistanceFieldValue );
			StripeColor.a *= smoothstep( 0.565f, 0.649f, DistanceFieldValue );
			float4 NoiseTexture = PdxTex2D( ProvinceEffectsNoise, MapCoords / WorldSpaceToTerrain0To1 * 0.005f );
			StripeColor.a = saturate( StripeColor.a + ( NoiseTexture.b - 0.5f) * 0.3f );
			float4 FinalColorWithAlpha = float4( Color, 1.0f );
			ApplyZigZagStripesCustom( FinalColorWithAlpha, StripeColor, 0.8f, MapCoords, DivergentRitesDiagonalStripesAngle, LineWidthFactor, ZigZagFrequency, ZigZagCurvature );
			Color = FinalColorWithAlpha.rgb;
		}

		void ApplyDivergentRitesColor( in float2 MapCoords, inout float3 Color, in EffectIntensities ConditionData )
		{
			ApplyDivergentRites( MapCoords, Color, ConditionData._DivergentRites, 0.0f );
		}

		void ApplyDivergentRitesFlatMapColor( in float2 MapCoords, inout float3 Color, in EffectIntensities ConditionData )
		{
			ApplyDivergentRites( MapCoords, Color, ConditionData._DivergentRites, 1.0f );
		}

		void ApplyProvinceEffectsDecal( in EffectIntensities ConditionData, inout float3 Diffuse, float2 MapCoords )
		{
			#ifdef LOW_SPEC_SHADERS
				return;
			#endif
			ApplyDroughtDiffuseDecal( Diffuse, ConditionData._Drought );
			DebugCondition( Diffuse.rgb, ConditionData );
		}

		void ApplyBurningColorOverlay( in float2 MapCoords, inout float3 Color, in float ConditionValue )
		{
			if ( ConditionValue <= SKIP_VALUE )
			{
				return;
			}
			const float ZoomedInZoomedOutFactor = saturate( ( CameraPosition.y - 350 ) / 900 );
			const float ZoomFadeFactor = smoothstep( 0.0f, 0.2f, ZoomedInZoomedOutFactor );
			if ( ZoomFadeFactor > SKIP_VALUE )
			{
				ConditionValue = pow( ConditionValue, 0.2f );
				ConditionValue *= 0.85f;
				float4 NoiseTexture = PdxTex2D( DiseaseTexture, MapCoords / WorldSpaceToTerrain0To1 * 0.002f );
				float4 NoiseTexture2 = PdxTex2D( DiseaseTexture2, MapCoords / WorldSpaceToTerrain0To1 * 0.002f );
				float DistanceFieldValue = CalcDistanceFieldValue( MapCoords );
				DistanceFieldValue = pow( DistanceFieldValue, 0.7f );
				DistanceFieldValue *= NoiseTexture2.a;
				float AnimationSpeed = GlobalTime * 1.5f;
				float PulseFactor = saturate( smoothstep( 0.0f, 1.0f, 1.0f - sin( AnimationSpeed - 1.484f ) * 0.5f ) );
				float EffectMask = smoothstep( 0.0f, 1.0f - ConditionValue * PulseFactor, DistanceFieldValue );
				EffectMask = lerp( 0.5f - ConditionValue * 0.5f, 0.15f + ConditionValue, EffectMask);
				EffectMask *= 0.9f;
				EffectMask = saturate( EffectMask );

				float3 EffectColor1 = float3( 0.0f, 0.0f, 0.0f );
				EffectColor1.r = NoiseTexture.r;

				float3 EffectColor2 = float3( 0.0f, 0.0f, 0.0f );
				EffectColor2.r = 1.0f - NoiseTexture.g;

				float Noise = NoiseTexture.r;

				float FastAnimPhase = 1.0f - frac( AnimationSpeed / PI * 0.5f ); //GlobalTime * 2.5f / (2π)
				float DistToPhase = abs( frac( Noise - FastAnimPhase + 0.5f ) - 0.5f ) * 2.0f;
				float FastGradient = smoothstep( 0.25f, 0.05f, DistToPhase );
				float3 FastGradientMask = smoothstep( 1.0f - EffectMask, 1.0f, Noise );
				FastGradientMask = lerp( FastGradientMask, float3( FastGradient, FastGradient, FastGradient ), 0.5f );
				float3 EffectColor = lerp( EffectColor1, EffectColor2, FastGradientMask );

				Color = lerp( Color, EffectColor, EffectMask * ZoomFadeFactor );
			}
		}
	]]
}
