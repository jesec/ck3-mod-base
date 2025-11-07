Includes = {
	"cw/utility.fxh"
	"cw/fullscreen_vertexshader.fxh"
	"cw/camera.fxh"
}

ConstantBuffer( 1 )
{
	float2 InvDownSampleSize;
	float2 ScreenResolution;
	float2 InvScreenResolution;
	float LumWhite2;
	float FixedExposureValue;
	float3 HSV;
	float BrightThreshold;
	float3 ColorBalance;
	float EmissiveBloomStrength;
	float3 LevelsMin;
	float MiddleGrey;
	float3 LevelsMax;

	float TonemapIndex;
	
	float TonemapShoulderStrength;
	float TonemapLinearStrength;
	float TonemapLinearAngle;
	float TonemapToeStrength;
	float TonemapToeNumerator;
	float TonemapToeDenominator;
	float TonemapLinearWhite;
	
	float Contrast;
	float Pivot;
};

PixelShader = 
{
	TextureSampler DepthBuffer
	{
		Ref = JominiDepthBuffer
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler DepthBufferMultiSampled
	{
		Ref = JominiDepthBufferMultiSampled
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		MultiSampled = yes
	}
	TextureSampler TonyMcMapfaceLUT
	{
		Index = 10
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		File = "gfx/FX/jomini/post_effect/tony_mc_mapface_2d.dds"
		srgb = no
	}

	Code
	[[
		static const float AgxMiddleGrey = 0.21f;
		static const float AgxSlope = 2.3f;
		static const float AgxToePower = 1.9f;
		static const float AgxShoulderPower = 3.1f;
		static const float AgxMinEv = -10.0f;
		static const float AgxMaxEv = 6.5f;
		static const float AgxSaturation = 1.0f;

		float SampleDepthBuffer( float2 UV, float2 Resolution )
		{
		#ifdef MULTI_SAMPLED
			int2 PixelIndex = int2( UV * Resolution );
			float Depth = PdxTex2DMultiSampled( DepthBufferMultiSampled, PixelIndex, 0 ).r;
		#else
			float Depth = PdxTex2DLod0( DepthBuffer, UV ).r;
		#endif
			return Depth;
		}
		float GetViewSpaceDepth( float2 UV, float2 Resolution )
		{
			float Depth = SampleDepthBuffer( UV, Resolution );
			return CalcViewSpaceDepth( Depth );
		}

		// Exposure 
		static const float3 LUMINANCE_VECTOR = float3( 0.2125, 0.7154, 0.0721 );
		static const float CubeSize = 32.0;
		float3 Exposure(float3 inColor)
		{
		#ifdef EXPOSURE_ADJUSTED
			float AverageLuminance = PdxTex2DLod0(AverageLuminanceTexture, vec2(0.5)).r;
			return inColor * (MiddleGrey / AverageLuminance);
		#endif

		#ifdef EXPOSURE_AUTO_KEY_ADJUSTED
			float AverageLuminance = PdxTex2DLod0(AverageLuminanceTexture, vec2(0.5)).r;
			float AutoKey = 1.13 - (2.0 / (2.0 + log10(AverageLuminance + 1.0)));
			return inColor * (AutoKey / AverageLuminance);
		#endif

		#ifdef EXPOSURE_FIXED
			return inColor * FixedExposureValue;
		#endif
		
			return inColor;
		}

		float3 ColorContrast( float3 Color )
		{
			Color = ( Color - Pivot ) * Contrast + Pivot;
			return Color;
		}

		// Tonemapping

		// Uncharted 2 - John Hable 2010
		float3 HableFunction(float3 color)
		{
			float a = TonemapShoulderStrength;
			float b = TonemapLinearStrength;
			float c = TonemapLinearAngle;
			float d = TonemapToeStrength;
			float e = TonemapToeNumerator;
			float f = TonemapToeDenominator;
			
			return color =  ( ( color * ( a * color + c * b ) + d * e ) / ( color * ( a * color + b ) + d * f ) ) - e / f;
		}
		float3 ToneMapUncharted2(float3 color)
		{
			float ExposureBias = 2.0;
			float3 curr = HableFunction( ExposureBias * color );

			float W = TonemapLinearWhite;
			float3 whiteScale = 1.0 / HableFunction( vec3 ( W ) );
			return saturate( curr * whiteScale );
		}

		// Filmic - John Hable
		float3 ToneMapFilmic_Hable(float3 color)
		{
			color = max( vec3( 0 ), color - 0.004f );
			color = saturate( ( color * (6.2 * color + 0.5) ) / ( color * (6.2 * color + 1.7 ) + 0.06 ) );
			return color;
		}
		
		// Aces filmic - Krzysztof Narkowicz
		float3 ToneMapAcesFilmic_Narkowicz(float3 color)
		{
			float a = 2.51f;
			float b = 0.03f;
			float c = 2.43f;
			float d = 0.89f;
			float e = 0.14f;

			color = saturate( ( color * ( a * color + b ) ) / ( color * ( c * color + d ) + e ) );
			return color;
		}


		// Aces filmic - Stephen Hill
		float3x3 SHInputMat()
		{
			return Create3x3(
				float3( 0.59719, 0.35458, 0.04823 ),
				float3( 0.07600, 0.90834, 0.01566 ),
				float3( 0.02840, 0.13383, 0.83777 ) );
		}
		float3x3 SHOutputMat()
		{
			return Create3x3(
				float3( 1.60475, -0.53108, -0.07367 ),
				float3( -0.10208,  1.10813, -0.00605 ),
				float3( -0.00327, -0.07276,  1.07602 ) );
		}
		float3 RRTAndODTFit( float3 v )
		{
			float3 a = v * ( v + 0.0245786f ) - 0.000090537f;
			float3 b = v * ( 0.983729f * v + 0.4329510f ) + 0.238081f;
			return a / b;
		}
		float3 ToneMapAcesFilmic_Hill( float3 color )
		{
			float ExposureBias = 1.8;
			color = color * ExposureBias;

			color = mul( SHInputMat(), color);
			color = RRTAndODTFit( color );
			color = mul( SHOutputMat(), color);

			return saturate( color );
		}

		// TonyMcMapface
		// Source: https://lettier.github.io/3d-game-shaders-for-beginners/lookup-table.html
		float3 ToneMapTonyMcMapface2DHorizontal(float3 Color)
		{
			Color = Color / ( Color + 1.0f );
			float CubeSize = 48;
			float Scale = ( CubeSize - 1.0f ) / CubeSize;
			float Offset = 0.5f / CubeSize;

			float X = ( ( Scale * Color.r + Offset ) / CubeSize );
			float Y = Scale * Color.g + Offset;

			float ZFloor = floor( ( Scale * Color.b + Offset ) * CubeSize );
			float XOffset1 = ZFloor / CubeSize;
			float XOffset2 = min( CubeSize - 1.0f, ZFloor + 1.0f ) / CubeSize;

			float3 Color1 = PdxTex2DLod0( TonyMcMapfaceLUT, float2( X + XOffset1, Y ) ).rgb;
			float3 Color2 = PdxTex2DLod0( TonyMcMapfaceLUT, float2( X + XOffset2, Y ) ).rgb;

			Color = lerp( Color1, Color2, Scale * Color.b * CubeSize - ZFloor );

			return Color;
		}

		// Uchimura 2017, "HDR theory and practice"
		// Math: https://www.desmos.com/calculator/gslcdxvipg
		// Source: https://www.slideshare.net/nikuque/hdr-theory-and-practicce-jp, https://github.com/dmnsgn/glsl-tone-map/blob/main/uchimura.glsl
		float3 UchimuraToneMap( float3 x, float P, float a, float m, float l, float c, float b )
		{
			float l0 = ( ( P - m ) * l ) / a;
			float L0 = m - m / a;
			float L1 = m + ( 1.0f - m ) / a;
			float S0 = m + l0;
			float S1 = m + a * l0;
			float C2 = ( a * P ) / ( P - S1 );
			float CP = -C2 / P;

			float3 w0 = 1.0f - smoothstep( 0.0f, m, x );
			float3 w2 = step( m + l0, x );
			float3 w1 = 1.0f - w0 - w2;

			float3 T = m * pow( x / m, c ) + b;
			float3 S = P - ( P - S1 ) * exp( CP * ( x - S0 ) );
			float3 L = m + a * ( x - m );

			return T * w0 + L * w1 + S * w2;
		}

		float3 UchimuraToneMap( float3 Color )
		{
			const float P = 1.0f;	// Max display brightness
			const float a = 1.0f;	// Contrast
			const float m = 0.22f;	// Linear section start
			const float l = 0.4f;	// Linear section length
			const float c = 1.33f;	// Black
			const float b = 0.0f;	// Pedestal

			return UchimuraToneMap( Color, P, a, m, l, c, b );
		}

		// AgX
		// Implementation based on https://iolite-engine.com/blog_posts/minimal_agx_implementation
		// Mean error^2: 3.6705141e-06
		float3 AgxDefaultContrastApprox( float3 x )
		{
			float3 x2 = x * x;
			float3 x4 = x2 * x2;

			return + 15.5f	* x4 * x2
				- 40.14f		* x4 * x
				+ 31.96f		* x4
				- 6.868f		* x2 * x
				+ 0.4298f	* x2
				+ 0.1191f	* x
				- 0.00232f;
		}

		float3 AgxImpl_Base( float3 Color )
		{
			const float3x3 AgxMat = float3x3(
				0.842479062253094f, 0.0423282422610123f, 0.0423756549057051f,
				0.0784335999999992f, 0.878468636469772f,  0.0784336f,
				0.0792237451477643f, 0.0791661274605434f, 0.879142973793104f
			);

			const float MinEv = -12.47393f;
			const float MaxEv = 4.026069f;

			
			// Input transform (inset)
			Color = mul( AgxMat, Color );

			// Log2 space encoding
			Color = clamp( log2( Color ), MinEv, MaxEv );
			Color = ( Color - MinEv ) / ( MaxEv - MinEv ) ;

			// Apply sigmoid function approximation
			Color = AgxDefaultContrastApprox( Color );

			return Color;
		}

		float3 AgxImpl_Eotf( float3 Color )
		{
			const float3x3 AgxMatInv = float3x3(
				 1.19687900512017f,   -0.0528968517574562f, -0.0529716355144438f,
				-0.0980208811401368f,  1.15190312990417f,   -0.0980434501171241f,
				-0.0990297440797205f, -0.0989611768448433f,  1.15107367264116f
			);
				
			// Inverse input transform (outset)
			Color = mul( AgxMatInv, Color );
			
			// sRGB IEC 61966-2-1 2.2 Exponent Reference EOTF Display
			// NOTE: We're linearizing the output here. Comment/adjust when
			// *not* using a sRGB render target
			Color = pow( Color, float3( 2.2f, 2.2f, 2.2f ) );

			return Color;
		}

		float3 ToneMapAgx( float3 Color )
		{
			Color = AgxImpl_Base( Color );
			Color = AgxImpl_Eotf( Color );
			return Color;
		}

		// AgX with custom input
		// https://www.shadertoy.com/view/dtSGD1
		float3 OpenDomainToNormalizedLog2( float3 OpenDomain, float MiddleGrey, float MinEv, float MaxEv )
		{
			float TotalExposure = MaxEv - MinEv;

			float3 OutputLog = clamp( log2( OpenDomain / MiddleGrey ), MinEv, MaxEv );

			return ( OutputLog - MinEv ) / TotalExposure;
		}

		float AgXScale( float XPivot, float YPivot, float SlopePivot, float Power )
		{
			return pow( pow( ( SlopePivot * XPivot ), -Power ) * ( pow( ( SlopePivot * ( XPivot / YPivot ) ), Power ) - 1.0 ), -1.0 / Power );
		}

		float AgXHyperbolic( float X, float Power )
		{
			return X / pow( 1.0f + pow( X, Power ), 1.0f / Power );
		}

		float AgXTerm( float X, float XPivot, float SlopePivot, float Scale )
		{
			return ( SlopePivot * ( X - XPivot ) ) / Scale;
		}

		float AgXCurve( float X, float XPivot, float YPivot, float SlopePivot, float ToePower, float ShoulderPower, float Scale )
		{
			if( Scale < 0.0f )
			{
				return Scale * AgXHyperbolic( AgXTerm( X, XPivot, SlopePivot, Scale ), ToePower ) + YPivot;
			}
			return Scale * AgXHyperbolic( AgXTerm( X, XPivot, SlopePivot, Scale ), ShoulderPower ) + YPivot;
		}

		float AgXFullCurve( float X, float XPivot, float YPivot, float SlopePivot, float ToePower, float ShoulderPower )
		{
			float ScaleXPivot = X >= XPivot ? 1.0f - XPivot : XPivot;
			float ScaleYPivot = X >= XPivot ? 1.0f - YPivot : YPivot;

			float ToeScale = AgXScale( ScaleXPivot, ScaleYPivot, SlopePivot, ToePower );
			float ShoulderScale = AgXScale( ScaleXPivot, ScaleYPivot, SlopePivot, ShoulderPower );

			float Scale = X >= XPivot ? ShoulderScale : -ToeScale;

			return AgXCurve( X, XPivot, YPivot, SlopePivot, ToePower, ShoulderPower, Scale );
		}

		float3 ToneMapAgx2( float3 Color )
		{
			float XPivot = abs( AgxMinEv ) / ( AgxMaxEv - AgxMinEv );
			float YPivot = 0.5f;

			float3 LogV = OpenDomainToNormalizedLog2( Color, AgxMiddleGrey, AgxMinEv, AgxMaxEv );

			float OutputR = AgXFullCurve( LogV.r, XPivot, YPivot, AgxSlope, AgxToePower, AgxShoulderPower );
			float OutputG = AgXFullCurve( LogV.g, XPivot, YPivot, AgxSlope, AgxToePower, AgxShoulderPower );
			float OutputB = AgXFullCurve( LogV.b, XPivot, YPivot, AgxSlope, AgxToePower, AgxShoulderPower );

			Color = clamp( float3( OutputR, OutputG, OutputB ), 0.0f, 1.0f );

			float3 LuminanceWeight = float3( 0.2126729f,  0.7151522f,  0.0721750f );
			float LuminancedColor = dot( Color, LuminanceWeight );
			float3 Desaturation = float3( LuminancedColor, LuminancedColor, LuminancedColor );
			Color = lerp( Desaturation, Color, AgxSaturation );
			Color = clamp( Color, 0.0f, 1.0f );

			return Color;
		}

#define TONEMAP_NONE 0
#define TONEMAP_REINHARD 1
#define TONEMAP_REINHARD_MODIFIED 2
#define TONEMAP_FILMIC_HABLE 3
#define TONEMAP_FILMICACES_NARKOWICZ 4
#define TONEMAP_FILMICACES_HILL 5
#define TONEMAP_UNCHARTED 6
#define TONEMAP_TONY_MCMAPFACE 7
#define TONEMAP_UCHIMURA 8
#define TONEMAP_AGX 9

		float3 ToneMap( float3 inColor )
		{
			uint Tonemap = TonemapIndex * 255.0;

			// Roughly in order of most used to least used
			if ( Tonemap == TONEMAP_UNCHARTED )
			{
				return ToGamma( ToneMapUncharted2( inColor ) );
			}
			else if ( Tonemap == TONEMAP_FILMICACES_HILL )
			{
				return ToGamma( ToneMapAcesFilmic_Hill( inColor ) );
			}
			else if ( Tonemap == TONEMAP_FILMICACES_NARKOWICZ )
			{
				return ToGamma( ToneMapAcesFilmic_Narkowicz( inColor ) );
			}
			else if ( Tonemap == TONEMAP_NONE )
			{
				return ToGamma( inColor );
			}
			else if ( Tonemap == TONEMAP_REINHARD )
			{
				float3 retColor = inColor / (1.0 + inColor);
				return ToGamma( saturate( retColor ) );
			}
			else if ( Tonemap == TONEMAP_REINHARD_MODIFIED )
			{
				float Luminance = dot( inColor, LUMINANCE_VECTOR );
				float LDRLuminance = ( Luminance * (1.0 + ( Luminance / 1.5f ) ) ) / ( 1.0 + Luminance );
				float vScale = LDRLuminance / Luminance;
				return ToGamma( saturate( inColor * vScale ) );
			}
			else if ( Tonemap == TONEMAP_FILMIC_HABLE )
			{
				return ToneMapFilmic_Hable( inColor );
			}
			else if ( Tonemap == TONEMAP_TONY_MCMAPFACE )
			{
				return ToGamma( ToneMapTonyMcMapface2DHorizontal( max( vec3( 0.0f ), inColor ) ) );
			}
			else if ( Tonemap == TONEMAP_UCHIMURA )
			{
				return ToGamma( UchimuraToneMap( inColor ) );
			}
			else if ( Tonemap == TONEMAP_AGX )
			{
				return ToneMapAgx2( inColor );
			}

			return ToGamma( inColor );
		}

	]]
}

