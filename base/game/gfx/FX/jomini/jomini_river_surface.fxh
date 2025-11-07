Includes = {
	"jomini/jomini_river.fxh"
	"jomini/jomini_water_default.fxh"
}

PixelShader =
{
	Code
	[[
		#ifndef JOMINIRIVER_GlobalTime
		#define JOMINIRIVER_GlobalTime GlobalTime
		#endif
		
		float4 CalcRiverSurface( in VS_OUTPUT_RIVER Input )
		{			
			float Depth = CalcDepth( Input.UV );
			
			SWaterParameters Params;
			Params._ScreenSpacePos = Input.Position;
			Params._WorldSpacePos = Input.WorldSpacePos;
			Params._WorldUV = Input.WorldSpacePos.xz / MapSize;
			Params._WorldUV.y = 1.0f - Params._WorldUV.y;
			Params._Depth = Depth * Input.Width + 0.1f;
			Params._NoiseScale = _NoiseScale;
			Params._WaveSpeedScale = _NoiseSpeed;
			Params._WaveNoiseFlattenMult = _FlattenMult;
			
			#ifdef WATER_LOCAL_SPACE_NORMALS
				Params._Normal = normalize(Input.Normal);
				Params._Tangent = normalize(Input.Tangent);
				Params._Bitangent = normalize( cross( Params._Normal, Params._Tangent ) );
			#endif
			
			float2 FlowNormalUV = Input.UV.yx * float2( 1.0f, -1.0f );
			FlowNormalUV.x -= 0.5f + sin( Input.UV.x * 0.2f + JOMINIRIVER_GlobalTime * 0.1f ) * 0.5f;
			FlowNormalUV *= float2( Input.Width, 1 ) * _FlowNormalUvScale;
			FlowNormalUV.y += JOMINIRIVER_GlobalTime * _FlowNormalSpeed;
			float4 FlowNormalSample = PdxTex2D( FlowNormalTexture, FlowNormalUV );
			FlowNormalUV.y += JOMINIRIVER_GlobalTime * _FlowNormalSpeed * 1.33f;
			FlowNormalSample += PdxTex2D( FlowNormalTexture, FlowNormalUV * 0.713f );
			FlowNormalSample *= 0.5f;
			
			float3 FlowNormal = UnpackNormal( FlowNormalSample ).xzy;
			FlowNormal.y *= _WaterFlowNormalFlatten * _FlattenMult * saturate( dot(Input.Normal, float3(0,1,0)) );
			Params._FlowNormal = normalize(FlowNormal);
			Params._FlowFoamMask = FlowNormalSample.a * _RiverFoamFactor;
			
			float4 Color = CalcWater( Params )._Color;
			Color.a = saturate( Depth * 2.0f / _Depth ) * Input.Transparency * saturate( ( Input.DistanceToMain - 0.1f ) * 5.0f );
			return Color;
		}

		SWaterOutput CalcRiverAdvanced( in VS_OUTPUT_RIVER Input )
		{			
			float Depth = CalcDepth( Input.UV );
			
			SWaterParameters Params;
			Params._ScreenSpacePos = Input.Position;
			Params._WorldSpacePos = Input.WorldSpacePos;
			Params._WorldUV = Input.WorldSpacePos.xz / MapSize;
			Params._WorldUV.y = 1.0f - Params._WorldUV.y;
			Params._Depth = Depth * Input.Width + 0.1f;
			Params._NoiseScale = _NoiseScale;
			Params._WaveSpeedScale = _NoiseSpeed;
			Params._WaveNoiseFlattenMult = _FlattenMult;
					
			#ifdef WATER_LOCAL_SPACE_NORMALS
				Params._Normal = normalize( Input.Normal );
				Params._Tangent = normalize( Input.Tangent );
				Params._Bitangent = normalize( cross( Params._Normal, Params._Tangent ) );
			#endif
			
			// Flow Movement
			float2 FlowNormalUV = Input.UV.yx * float2( 1.0f, -1.0f );
			FlowNormalUV *= float2( Input.Width, 1.0f ) * _FlowNormalUvScale;
			FlowNormalUV.y += JOMINIRIVER_GlobalTime * _FlowNormalSpeed;
			float4 FlowNormalSample = PdxTex2D( FlowNormalTexture, FlowNormalUV );
			
			float3 FlowNormal = UnpackNormal( FlowNormalSample ).xzy;
			FlowNormal.y *= _WaterFlowNormalFlatten * _FlattenMult * saturate( dot( Input.Normal, float3( 0.0f, 1.0f, 0.0f ) ) );
			Params._FlowNormal = normalize( FlowNormal );
			Params._FlowFoamMask = FlowNormalSample.a * _RiverFoamFactor;

			// Water color
			SWaterOutput Out = CalcWater( Params );
			
			// Ocean and river connection fade
			#ifdef JOMINI_REFRACTION_ENABLED
				Out._Color.a = Input.Transparency * saturate( ( Input.DistanceToMain - 0.1f ) * 5.0f );
			#endif

			// Edge fade
			float EdgeFade1 = smoothstep( 0.0f, _BankFade, Input.UV.y );
			float EdgeFade2 = smoothstep( 0.0f, _BankFade, 1.0f - Input.UV.y );
			Out._Color.a *= EdgeFade1 * EdgeFade2;

			return Out;
		}
	]]
}

BlendState BlendState
{
	BlendEnable = yes
	SourceBlend = "src_alpha"
	DestBlend = "inv_src_alpha"
	WriteMask = "RED|GREEN|BLUE"
}

RasterizerState RasterizerState
{
	DepthBias = -50000
}

DepthStencilState DepthStencilState
{
	DepthWriteEnable = no
}