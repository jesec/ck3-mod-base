PixelShader = 
{
	Code
	[[
		void DitheredOpacity( in float Opacity, in float2 NoiseCoordinate )
		{
			const float4x4 ThresholdMatrix =
			{
				1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
				13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
				4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
				16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
			};
			float Factor = ThresholdMatrix[NoiseCoordinate.x % 4][NoiseCoordinate.y % 4];
			clip( Opacity - Factor * sign( Opacity ) );
		}
	]]
}