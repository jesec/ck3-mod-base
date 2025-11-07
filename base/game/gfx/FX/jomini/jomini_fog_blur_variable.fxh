PixelShader = {
	Code
	[[
		//#define DEBUG_DEPTH_MASK

		// Performance Optimization
		static const float FogBlurSkipValue = 0.01f;

		// Height Blend Factor
		static const float BlurBeginHeight = 100.0f;
		static const float BlurEndHeight = 200.0f;

		// Depth Mask Adjustment Parameters : These parameters will affect the range of the blur.
		static const float DepthScale = 4.0f;
		static const float DepthMin = 0.0f;
		static const float DepthMax = 1.0f;

		// Blur Effect Adjustment Parameters : These parameters will affect how the blur looks.
		static const float BlurSampleCount = 8.0f;
		static const float DepthSampleOffset = 0.1f;
		static const float BlurSampleRadius = 0.001f;
		static const float BlurTint = 3.0f;
	]]
}