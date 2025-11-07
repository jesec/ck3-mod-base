Includes = {
	"cw/lighting.fxh"
	"cw/camera.fxh"
}

PixelShader =
{
	Code
	[[
		// Spherical coordinate constants for easier sun positioning (0-1 range)
		#define AZIMUTH_NORTH       0.0f     // 0.0 = north
		#define AZIMUTH_NORTHEAST   0.125f   // 1/8 turn
		#define AZIMUTH_EAST        0.25f    // 1/4 turn
		#define AZIMUTH_SOUTHEAST   0.375f   // 3/8 turn
		#define AZIMUTH_SOUTH       0.5f     // 1/2 turn
		#define AZIMUTH_SOUTHWEST   0.625f   // 5/8 turn
		#define AZIMUTH_WEST        0.75f    // 3/4 turn
		#define AZIMUTH_NORTHWEST   0.875f   // 7/8 turn

		#define ELEVATION_HORIZON   0.0f     // 0.0 = horizon
		#define ELEVATION_LOW       0.167f   // ~15 degrees
		#define ELEVATION_MID       0.333f   // ~30 degrees
		#define ELEVATION_HIGH      0.5f     // 45 degrees
		#define ELEVATION_STEEP     0.667f   // ~60 degrees
		#define ELEVATION_ZENITH    1.0f     // 90 degrees (straight up)

		float4x4 Float4x4Identity()
		{
			return float4x4( 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0 );
		}

		// Convert normalized spherical coordinates (0-1) to 3D direction vector
		// azimuth: horizontal direction (0.0 = north, 0.25 = east, 0.5 = south, 0.75 = west, 1.0 = north again)
		// elevation: vertical angle (0.0 = horizon, 0.5 = 45 degrees up, 1.0 = zenith/straight up)
		//
		// Quick reference:
		// Azimuth: 0.0=N, 0.125=NE, 0.25=E, 0.375=SE, 0.5=S, 0.625=SW, 0.75=W, 0.875=NW
		// Elevation: 0.0=horizon, 0.167=~15°, 0.33=~30°, 0.5=45°, 0.67=~60°, 1.0=zenith
		//
		// Examples:
		// - SphericalToDirection(0.0, 0.5) = north, 45 degrees up
		// - SphericalToDirection(0.25, 0.33) = east, ~30 degrees up
		// - SphericalToDirection(0.875, 0.167) = northwest, ~15 degrees up
		float3 SphericalToDirection( float Azimuth01, float Elevation01 )
		{
			// Convert 0-1 coordinates to radians
			// Azimuth: 0-1 maps to 0-2*PI, but we start from north (PI/2) instead of east (0) // 2.0f * 3.14159265f = 6.2831853
			float AzimuthRadians = ( Azimuth01 * 6.2831853f ) + 1.570796325f;
			// Elevation: 0-1 maps to 0-PI/2
			float ElevationRadians = Elevation01 * 1.570796325f; //3.14159265f * 0.5f = 1.570796325f

			float CosElevation = cos( ElevationRadians );
			return normalize( float3(
				CosElevation * cos( AzimuthRadians ),	// X component
				sin( ElevationRadians ),				// Y component (up)
				CosElevation * sin( AzimuthRadians )	// Z component
			) );
		}

		SMaterialProperties GetMaterialProperties( float3 SampledDiffuse, float3 Normal, float SampledRoughness, float SampledSpec, float SampledMetalness )
		{
			SMaterialProperties MaterialProps;

			MaterialProps._PerceptualRoughness = SampledRoughness;
			MaterialProps._Roughness = RoughnessFromPerceptualRoughness( MaterialProps._PerceptualRoughness );

			float SpecRemapped = RemapSpec( SampledSpec );
			MaterialProps._Metalness = SampledMetalness;

			MaterialProps._DiffuseColor = MetalnessToDiffuse( MaterialProps._Metalness, SampledDiffuse );
			MaterialProps._SpecularColor = MetalnessToSpec( MaterialProps._Metalness, SampledDiffuse, SpecRemapped );

			MaterialProps._Normal = Normal;

			return MaterialProps;
		}


		// Luminance-preserving darkening with soft toe to minimum value
		// Darkens color while preserving hue and saturation, with a floor to prevent clipping to black
		float3 ApplyOvercastContrast( float3 Color, float BlendAmount )
		{
			float CurrentLuminance = dot( Color, float3( 0.299f, 0.587f, 0.114f ) );
			float MinLuminance = 0.008f; // Minimum brightness floor to prevent clipping

			// Soft toe using power curve - asymptotically approaches minimum
			float LuminanceRange = CurrentLuminance - MinLuminance;
			float DarkenedRange = LuminanceRange * ( 1.0f - BlendAmount );
			float TargetLuminance = MinLuminance + DarkenedRange;

			// Scale RGB proportionally to achieve target luminance (preserves hue/saturation)
			return Color * ( TargetLuminance / max( CurrentLuminance, 0.001f ) );
		}
	]]
}
