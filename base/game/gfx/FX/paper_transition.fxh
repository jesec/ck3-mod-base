PixelShader = {
    TextureSampler PaperTearMask
	{
		Index = 8
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		File = "gfx/map/terrain/flat_maps/paper_tear_mask.dds"
		srgb = yes
	}

	Code
	[[
		float CalculatePaperTransitionBlend(
			float2 UV,
			float TransitionAmount,
			float2 MainUVScale = float2( 12.0f, 6.0f ),
			float2 DetailUVScale = float2( 16.0f, 8.0f ),
			float2 LargeUVScale = float2( 1.0f, 1.0f ) )
		{
			if ( TransitionAmount >= 1.0f )
			{
				return 1.0f;
			}
			if ( TransitionAmount <= 0.001f )
			{
				return 0.0f;
			}
			// Sample different channels at different scales
			float2 MaskUV_R = float2( UV.x * MainUVScale.x, UV.y * MainUVScale.y );
			float2 MaskUV_G = float2( UV.x * DetailUVScale.x, UV.y * DetailUVScale.y );
			float2 MaskUV_B = float2( UV.x * LargeUVScale.x, UV.y * LargeUVScale.y );
			
			// Sample each channel separately
			float MaskVal = PdxTex2D( PaperTearMask, MaskUV_R ).r;
			float Variation = PdxTex2D( PaperTearMask, MaskUV_G ).g;
			float LargeScale = PdxTex2D( PaperTearMask, MaskUV_B ).b;
			
			// Combine the main mask with large scale
			MaskVal = MaskVal * 0.5f + LargeScale * 0.5f;
			
			// Calculate threshold with large scale modulation
			float Threshold = 1.2f - TransitionAmount * 1.4f;
			Threshold += ( LargeScale - 0.5f ) * 0.3f;
			float BlendBase = Threshold + Variation;
			// Calculate final blend
			float Blend = smoothstep(
				BlendBase - 0.35f,
				BlendBase + 0.35f,
				MaskVal
			);
			
			return Blend;
		}
	]]
}