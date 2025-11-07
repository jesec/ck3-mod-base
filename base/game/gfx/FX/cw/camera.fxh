ConstantBuffer( PdxCamera )
{
	float4x4	ViewProjectionMatrix;
	float4x4	InvViewProjectionMatrix;
	float4x4	ViewMatrix;
	float4x4	InvViewMatrix;
	float4x4	ProjectionMatrix;
	float4x4	InvProjectionMatrix;

	float4x4 	ShadowMapTextureMatrix;
	
	float3		CameraPosition;
	float		ZNear;
	float3		CameraLookAtDir;
	float		ZFar;
	float3		CameraUpDir;
	float 		CameraFoV;
	float3		CameraRightDir;
	float 		_UpscaleLodBias;
	float 		_UpscaleLodBiasNative;
	float 		_UpscaleLodBiasMultiplier;
	float 		_UpscaleLodBiasMultiplierNative;
	float 		_UpscaleLodBiasEnabled;
}

Code
[[
	#define ZoomInHeight 100.0 // This could impact a significant number of terrain-related shaders, so please exercise caution before making any changes.
	#define ZoomOutHeight 750.0 // This could impact a significant number of terrain-related shaders, so please exercise caution before making any changes.

	float CalcViewSpaceDepth( float Depth )
	{
		Depth = 2.0f * Depth - 1.0f;
		float ZLinear = 2.0f * ZNear * ZFar / ( ZFar + ZNear - Depth * ( ZFar - ZNear ) );
		return ZLinear;
	}
	
	float3 ViewSpacePosFromDepth( float Depth, float2 UV )
	{
		float x = UV.x * 2.0f - 1.0f;
		float y = ( 1.0f - UV.y ) * 2.0f - 1.0f;
		
		float4 ProjectedPos = float4( x, y, Depth, 1.0f );
		
		float4 ViewSpacePos = mul( InvProjectionMatrix, ProjectedPos );
		
		return ViewSpacePos.xyz / ViewSpacePos.w;
	}
	
	float3 WorldSpacePositionFromDepth( float Depth, float2 UV )
	{
		float3 WorldSpacePos = mul( InvViewMatrix, float4( ViewSpacePosFromDepth( Depth, UV ), 1.0f ) ).xyz;
		return WorldSpacePos;  
	}
	
	float GetZoomedInZoomedOutFactor()
	{
		return saturate( ( CameraPosition.y - ZoomInHeight ) / ( ZoomOutHeight - ZoomInHeight + 1e-5 ) );
	}
]]
