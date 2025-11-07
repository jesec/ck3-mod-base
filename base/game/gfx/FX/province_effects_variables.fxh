PixelShader = {
	Code
	[[
		static const int DROUGHT_INDEX = 1;
		static const int FLOOD_INDEX = 2;
		static const int SUMMER_INDEX = 3;
		static const int SNOW_INDEX = 4;

		// General
		#define OpacityLowImpactValue				0.1f
		#define OpacityHighImpactValue				1.0f

		// Drought
		#define DroughtBlendWeight					1.00f
		#define DroughtSlopeMin						0.2f
		#define DroughtPreSaturation				0.8f
		#define DroughtPreValue						0.8f
		#define DroughtFinalSaturation				0.7f
		#define DroughtOverlayColor					float3( 0.7020f, 0.3569f, 0.0f )
		#define DroughtDryOverlayColor				float3( 0.200f, 0.133f, 0.078f )
		#define DroughtCracksOverlayColor			float3( 0.357f, 0.188f, 0.047f )

		#define DroughtColorMaskPositionFrom		1.0f
		#define DroughtColorMaskPositionTo			0.1f

		#define DroughtColorMaskContrastFrom		1.0f
		#define DroughtColorMaskContrastTo			0.9f

		#define DroughtDryTexureIndex				0
		#define DroughtDryMaskUVTiling				15
		#define DroughtDryTextureBlendWeight		0.35f
		#define DroughtDryTextureBlendContrast		1.8f
		
		#define DroughtDryMaskPositionFrom			1.05f
		#define DroughtDryMaskPositionTo			0.60f

		#define DroughtDryMaskContrastFrom			0.455f
		#define DroughtDryMaskContrastTo			0.905f


		#define DroughtCracksTexureIndex			1
		#define DroughtCrackedTextureUVTiling		2
		#define DroughtCracksAreaMaskTiling			10.0f

		#define DroughtCracksAreaMaskPositionFrom	0.7f
		#define DroughtCracksAreaMaskPositionTo		0.6f
		
		#define DroughtCracksAreaMaskContrastFrom	0.7f
		#define DroughtCracksAreaMaskContrastTo		0.101f

		#define DroughtCracksTextureBlendWeight		0.28f
		#define DroughtCracksTextureBlendContrast	1.5f

		#define DroughtOverlayTree 					float3( 1.0f, 0.5569f, 0.4549f)

		#define DroughtDecalPreSaturation 			0.0f
		#define DroughtDecalPreValue 				0.8f
		#define DroughtDecalFinalSaturation 		0.4f
		#define DroughtOverlayDecal 				float3( 0.7020f, 0.3569f, 0.0f )

		// Flooding
		#define FloodSlopeMin						0.98f
		#define FloodTextureIndex					2

		#define FloodNoiseTiling					30
		#define FloodDetailTiling					0.5f
		
		#define FloodWaterOpacity 					0.92f
		#define FloodWaterPropertiesBlend			0.995f
		#define FloodNormalDirection				float3( 0.0f, 0.0f, 1.0f )
		#define FloodPropertiesSettings 			float4( 0.0f, 0.03f, 0.0f, 0.1f )
		
		#define FloodDiffuseWetMultiplier			0.5f
		#define FloodPropertiesWetMultiplier		0.60f
		#define FloodNoisePositionFrom				0.75f
		#define FloodNoisePositionTo				0.5f
		#define FloodNoiseContrastFrom				0.1f
		#define FloodNoiseContrastTo				0.45f

		#define FloodWaterInnerColor				float3( 0.0392f, 0.0353f, 0.0078f )
		#define FloodWaterEdgeColor					float3( 0.0275f, 0.0471f, 0.0902f )

		// Summer
		#define SummerBlendWeight					1.0f
		#define SummerSlopeMin						0.2f
		#define SummerGrassOverlayColor 			float3( 0.2824f, 0.4471f, 0.1216f )

		#define SummerGrassTexureIndex				3
		#define SummerGrassMaskUVTiling				15
		#define SummerGrassTextureBlendWeight		0.5f
		
		#define SummerGrassMaskPositionFrom			1.05f
		#define SummerGrassMaskPositionTo			0.50f

		#define SummerGrassMaskContrastFrom			0.455f
		#define SummerGrassMaskContrastTo			0.905f
		#define SummerOverlayTree					float3( 0.4196f, 0.6941f, 0.4078f) 
	]]
}