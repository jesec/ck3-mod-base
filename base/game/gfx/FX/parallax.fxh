Code
[[
	float2 ParallaxMappingLowSpec( PdxTextureSampler2D ParallaxMap, float2 UV, float3 Tangent, float3 Bitangent, float3 Normal, float3 WorldSpacePos, float3 CameraPosition )
	{
		//		Single Texture Sample Parallax Occlusion Mapping for lowspec machines
		//		Requires a height map (grayscale texture) that defines how much a pixel portrudes from the surface.
		//		Less effective than ParallaxMapping(...) below, but still provides a certain depth effect.
		
		static const float HeightStrength = 0.01f;
		
		float3x3 TBN = Create3x3( normalize( Tangent ), normalize( Bitangent ), normalize( Normal ) );
		float3 ViewDir = mul(TBN, ( CameraPosition - WorldSpacePos ) );
		ViewDir = normalize( ViewDir );
		
		float Height = PdxTex2D( ParallaxMap, UV ).r;
		
		Height -= 0.5f;
		Height *= 2.0f;
		Height = clamp(Height, 0.0f, 1.0f);
		
		float2 OffsetUV = UV + ( ViewDir.xy * Height * HeightStrength );
		
		return OffsetUV;
	}
	
	float2 ParallaxMapping( PdxTextureSampler2D ParallaxMap, float2 UV, float3 Tangent, float3 Bitangent, float3 Normal, float3 WorldSpacePos, float3 CameraPosition )
	{
		//		Layer-Based Parallax Occlusion Mapping (https://learnopengl.com/Advanced-Lighting/Parallax-Mapping)
		//		Requires a height map (grayscale texture) that defines how much a pixel protrudes from the surface.
		//		Increasing NumLayers will be more costly (amount of texture samples) but provide more accurate results.
		//		Increasing StepDepth will increase the amount each step (layer) protrudes out.
		
		static const float NumLayers = 18;
		static const float LayerDepth = 1.0f / NumLayers;
		static const float StepDepth = 0.045f;
		
		float CurrentLayerDepth = 0.0f;
		
		float3x3 TBN = Create3x3( normalize( Tangent ), normalize( Bitangent ), normalize( Normal ) );
		float3 ViewDir = normalize( WorldSpacePos - CameraPosition );
		ViewDir = mul( TBN, ViewDir );
		
		float2 P = ViewDir.xy * StepDepth;
		float2 DeltaUV = P / NumLayers;
		
		float CurrentDepthValue = PdxTex2D( ParallaxMap, UV ).r;
		
		for (int i = 0; i < NumLayers; i++)
		{
			if ( CurrentLayerDepth < CurrentDepthValue )
			{
				UV -= DeltaUV;
				CurrentDepthValue = PdxTex2D( ParallaxMap, UV ).r;
				CurrentLayerDepth += LayerDepth;
			}
		}
		
		float2 PrevUV = UV + DeltaUV;
		float AfterDepth = CurrentDepthValue - CurrentLayerDepth;
		float BeforeDepth = PdxTex2D( ParallaxMap, PrevUV ).r - CurrentLayerDepth + LayerDepth;
		
		float Weight = AfterDepth / ( AfterDepth - BeforeDepth );
		float2 OffsetUV = PrevUV * Weight + UV * (1.0f - Weight);
		
		return OffsetUV;
	}
]]