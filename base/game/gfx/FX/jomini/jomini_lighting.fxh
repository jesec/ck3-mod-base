Includes = {
	"cw/lighting_util.fxh"
	"cw/shadow.fxh"
	"jomini/jomini.fxh"
	"constants.fxh"
}

PixelShader = 
{
	Code
	[[
		//-------------------------------
		// Common lighting functions ----
		//-------------------------------
		SLightingProperties GetSunLightingProperties( float3 WorldSpacePos, float ShadowTerm )
		{
			SLightingProperties LightingProps;
			LightingProps._ToCameraDir = normalize( CameraPosition - WorldSpacePos );
			LightingProps._ToLightDir = ToSunDir;
			LightingProps._LightIntensity = SunDiffuse * SunIntensity;
			LightingProps._ShadowTerm = ShadowTerm;
			LightingProps._CubemapIntensity = CubemapIntensity;
			LightingProps._CubemapYRotation = CubemapYRotation;
			
			return LightingProps;
		}

		SLightingProperties GetMapUIElementsSunLightingProperties( float3 WorldSpacePos, float ShadowTerm )
		{
			SLightingProperties LightingProps;
			LightingProps._ToCameraDir = normalize( CameraPosition - WorldSpacePos );
			// Map UI elements are lit from above instead of from the sun.
			// THis causes the elements to be brighter in the center of the screen
			LightingProps._ToLightDir = float3(0.0, 1.0, 0.3);
			LightingProps._LightIntensity = SunDiffuse * SunIntensity;
			LightingProps._ShadowTerm = ShadowTerm;
			LightingProps._CubemapIntensity = CubemapIntensity;
			LightingProps._CubemapYRotation = CubemapYRotation;
			
			return LightingProps;
		}
		
		SLightingProperties GetSunLightingProperties( float3 WorldSpacePos, PdxTextureSampler2DCmp ShadowMap )
		{
			float4 ShadowProj = mul( ShadowMapTextureMatrix, float4( WorldSpacePos, 1.0 ) );
			float ShadowTerm = CalculateShadow( ShadowProj, ShadowMap );
			
			return GetSunLightingProperties( WorldSpacePos, ShadowTerm );
		}
		
		float3 CalculateSunLighting( SMaterialProperties MaterialProps, SLightingProperties LightingProps, PdxTextureSamplerCube EnvironmentMap )
		{
			float3 DiffuseLight;
			float3 SpecularLight;
			CalculateLightingFromLight( MaterialProps, LightingProps, DiffuseLight, SpecularLight );
			
			float3 DiffuseIBL;
			float3 SpecularIBL;
			CalculateLightingFromIBL( MaterialProps, LightingProps, EnvironmentMap, DiffuseIBL, SpecularIBL );
			
			return DiffuseLight + SpecularLight + DiffuseIBL + SpecularIBL;
		}

		// Special lighting for map objects to make them more visible
		float3 CalculateMapObjectsSunLighting( SMaterialProperties MaterialProps, SLightingProperties LightingProps, PdxTextureSamplerCube EnvironmentMap )
		{
			float3 DiffuseLight;
			float3 SpecularLight;
			CalculateLightingFromLight( MaterialProps, LightingProps, DiffuseLight, SpecularLight );
			
			float3 DiffuseIBL;
			float3 SpecularIBL;
			CalculateLightingFromIBL( MaterialProps, LightingProps, EnvironmentMap, DiffuseIBL, SpecularIBL );
			
			return ( DiffuseLight * MapObjectsDiffuseLightScale + SpecularLight * MapObjectsSpecularLightScale + DiffuseIBL * MapObjectsDiffuseIBLScale + SpecularIBL * MapObjectsSpecularIBLScale );
		}

		// Special lighting for map text, borders and such
		float3 CalculateMapUIElementsSunLighting( SMaterialProperties MaterialProps, SLightingProperties LightingProps, PdxTextureSamplerCube EnvironmentMap )
		{
			float3 DiffuseLight;
			float3 SpecularLight;
			CalculateLightingFromLight( MaterialProps, LightingProps, DiffuseLight, SpecularLight );
			
			float3 DiffuseIBL;
			float3 SpecularIBL;
			CalculateLightingFromIBL( MaterialProps, LightingProps, EnvironmentMap, DiffuseIBL, SpecularIBL );
			
			return ( DiffuseLight * MapObjectsDiffuseLightScale + SpecularLight * MapObjectsSpecularLightScale + DiffuseIBL * MapObjectsDiffuseIBLScale + SpecularIBL * MapObjectsSpecularIBLScale );
		}
		
		//-------------------------------
		// Debugging --------------------
		//-------------------------------
		//#define PDX_DEBUG_NORMAL
		//#define PDX_DEBUG_DIFFUSE
		//#define PDX_DEBUG_SPEC
		//#define PDX_DEBUG_SPEC_RANGES
		//#define PDX_DEBUG_ROUGHNESS
		//#define PDX_DEBUG_METALNESS
		//#define PDX_DEBUG_SHADOW
		//#define PDX_DEBUG_SUN_LIGHT_SIMPLE_DIFFUSE // AKA Daniel mode
		//#define PDX_DEBUG_SUN_LIGHT_ONLY_SPECULAR
		//#define PDX_DEBUG_SUN_LIGHT
		//#define PDX_DEBUG_SUN_LIGHT_WITH_SHADOW
		//#define PDX_DEBUG_IBL_SIMPLE_DIFFUSE
		//#define PDX_DEBUG_IBL_DIFFUSE
		//#define PDX_DEBUG_IBL_SPECULAR
		//#define PDX_DEBUG_IBL

		void DebugReturn( inout float3 Out, SMaterialProperties MaterialProps, SLightingProperties LightingProps )
		{
		#ifdef PDX_DEBUG_NORMAL
			Out = saturate( MaterialProps._Normal );
		#endif
		
		#ifdef PDX_DEBUG_DIFFUSE
			Out = MaterialProps._DiffuseColor;
		#endif
		
		#ifdef PDX_DEBUG_SPEC
			Out = MaterialProps._SpecularColor;
		#endif
		
		#ifdef PDX_DEBUG_ROUGHNESS
			Out = vec3( MaterialProps._PerceptualRoughness );
		#endif
		
		#ifdef PDX_DEBUG_METALNESS
			Out = vec3( MaterialProps._Metalness );
		#endif
		
		#ifdef PDX_DEBUG_SPEC_RANGES
			// Shows extremely low specular values in red
			// Shows common material values in green (2-6%)
			// Shows gemstone material values in yellow (8-17%)
			// Shows metalness in blue
			// Shows everything else in gray scale	
			// Values based on page 14-15 in http://renderwonk.com/publications/s2010-shading-course/hoffman/s2010_physically_based_shading_hoffman_a_notes.pdf
			float Spec = MaterialProps._SpecularColor.r;
			
			float e = 0.002f;
			float ErrorThreshold = 0.01f;
			float DielectricLow = 0.02f;
			float DielectricHigh = 0.06f;
			float GemstoneLow = 0.08f;
			float GemstoneHigh = 0.17f;
			
			float Error = smoothstep( ErrorThreshold, 0.0, Spec );
			float CommonMask = smoothstep( DielectricLow-e, DielectricLow, Spec ) * smoothstep( DielectricHigh+e, DielectricHigh, Spec);
			float GemstoneMask = smoothstep( GemstoneLow-e, GemstoneLow, Spec ) * smoothstep( GemstoneHigh+e, GemstoneHigh, Spec);
			float ScaledSpec = ( Spec / RemapSpec(1.0f) );
			float3 DebugSpecColor = float3( GemstoneMask, CommonMask + GemstoneMask, 0.0 ) * ScaledSpec;
			Out = lerp( vec3(ScaledSpec), DebugSpecColor, CommonMask + GemstoneMask );
			Out = lerp( Out, float3(1.0,0.0,0.0), Error );
			Out = lerp( Out, float3(0.0,0.0,1.0), MaterialProps._Metalness );
		#endif
		
		#ifdef PDX_DEBUG_SHADOW
			Out = vec3( LightingProps._ShadowTerm );
		#endif
		
		#ifdef PDX_DEBUG_SUN_LIGHT_SIMPLE_DIFFUSE
			SMaterialProperties MaterialPropsCopy = MaterialProps;
			MaterialPropsCopy._DiffuseColor = vec3( 1.0 );
			MaterialPropsCopy._SpecularColor = vec3( 0.0 );
			
			float3 SpecularLight;
			CalculateLightingFromLight( MaterialPropsCopy, LightingProps, Out, SpecularLight );
		#endif
		
		#ifdef PDX_DEBUG_SUN_LIGHT_ONLY_SPECULAR			
			float3 DiffuseLight;			
			CalculateLightingFromLight( MaterialProps, LightingProps, DiffuseLight, Out );
		#endif
		
		#if defined( PDX_DEBUG_SUN_LIGHT ) || defined( PDX_DEBUG_SUN_LIGHT_WITH_SHADOW )
			float3 DiffuseLight;
			float3 SpecularLight;

			#ifdef PDX_DEBUG_SUN_LIGHT_WITH_SHADOW
				CalculateLightingFromLight( MaterialProps, LightingProps, DiffuseLight, SpecularLight );
			#else
				SLightingProperties LightingPropsNoShadow = LightingProps;
				LightingPropsNoShadow._ShadowTerm = 1.0;
				CalculateLightingFromLight( MaterialProps, LightingPropsNoShadow, DiffuseLight, SpecularLight );
			#endif
			
			Out = DiffuseLight + SpecularLight;
		#endif
		}

		void DebugReturn( inout float3 Out, SMaterialProperties MaterialProps, SLightingProperties LightingProps, PdxTextureSamplerCube EnvironmentMap )
		{
			DebugReturn( Out, MaterialProps, LightingProps );
		
		#if defined( PDX_DEBUG_IBL ) || defined( PDX_DEBUG_IBL_DIFFUSE ) || defined( PDX_DEBUG_IBL_SPECULAR ) || defined( PDX_DEBUG_IBL_SIMPLE_DIFFUSE )
			float3 DiffuseIBL;
			float3 SpecularIBL;
			
			SMaterialProperties MaterialPropsCopy = MaterialProps;
			#ifdef PDX_DEBUG_IBL_SIMPLE_DIFFUSE
				MaterialPropsCopy._DiffuseColor = vec3( 1.0 );
			#endif
			
			CalculateLightingFromIBL( MaterialPropsCopy, LightingProps, EnvironmentMap, DiffuseIBL, SpecularIBL );
			
			#if defined( PDX_DEBUG_IBL_DIFFUSE ) || defined( PDX_DEBUG_IBL_SIMPLE_DIFFUSE )
				Out = DiffuseIBL;
			#endif
			#ifdef PDX_DEBUG_IBL_SPECULAR
				Out = SpecularIBL;
			#endif
			#ifdef PDX_DEBUG_IBL
				Out = DiffuseIBL + SpecularIBL;
			#endif
		#endif
		}
	]]
}
