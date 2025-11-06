Includes = {
	"cw/camera.fxh"
}

ConstantBuffer( PdxFlipbookConstants )
{
	int2 FlipbookDimensions;
};

VertexStruct VS_INPUT_PARTICLE
{
	float2 UV0      		: TEXCOORD0;
	float4 Pos      		: TEXCOORD1; //	Pos.w contains the flipbook time.
	float4 RotQ     		: TEXCOORD2; // Rotation relative to world or camera when billboarded. 
	float2 Size     		: TEXCOORD3;
	float3 BillboardAxis	: TEXCOORD4;
	float4 Color    		: TEXCOORD5;
};

VertexStruct VS_OUTPUT_PARTICLE
{
    float4 Pos     			: PDX_POSITION;
	float4 Color   			: COLOR;
	float2 UV0     			: TEXCOORD0;
	float3 WorldSpacePos	: TEXCOORD1;
};

Code
[[
	float3 QRotVector( float4 RotQ, float3 V )
	{
		return V + 2.0 * cross( RotQ.xyz, cross( RotQ.xyz, V ) + RotQ.w * V );
	}

	float2 CalcCellUV( float2 UV, int Columns, int Rows, float Time )
	{
		int TotalFrames = ( Columns * Rows );
		uint CurrentFrame = uint( TotalFrames * Time );
		float2 CellUV;
		CellUV.x = float( CurrentFrame % Columns ) / Columns;
		CellUV.y = float( CurrentFrame / Columns ) / Rows;
		
		UV.x = ( UV.x / Columns );
		UV.y = ( UV.y / Rows );
		
		return CellUV + UV;
	}
]]

VertexShader =
{
	MainCode VertexParticle
	{				
		Input = "VS_INPUT_PARTICLE"
		Output = "VS_OUTPUT_PARTICLE"
		Code
		[[
			PDX_MAIN
			{
				VS_OUTPUT_PARTICLE Out;
				float3 InitialOffset = float3( (Input.UV0 - 0.5f) * Input.Size, 0 );
				float3 Offset = QRotVector( Input.RotQ, InitialOffset );

				#ifdef BILLBOARD
					float3 WorldPos = Input.Pos.xyz + Offset.x * CameraRightDir + Offset.y * CameraUpDir;
					
					if( Input.BillboardAxis.x != 0.0 || 
						Input.BillboardAxis.y != 0.0 || 
						Input.BillboardAxis.z != 0.0 )
					{
						float3 TextureAxis = float3(1,0,0);
						float4 Q;
						
						float DotProduct = dot(TextureAxis, Input.BillboardAxis);
						if(DotProduct < -0.999999f)
						{
							Q.xyzw = float4(0,0,1,0);
						}
						else
						{
							Q.xyz = cross(Input.BillboardAxis, TextureAxis);
							Q.w = sqrt(1 + DotProduct);
							Q = normalize(Q);
						}
						
						Offset = QRotVector( Q, InitialOffset );
						
						float3 RotatedBillboardAxis = QRotVector( Input.RotQ, Input.BillboardAxis );
						float3 ToCameraDir = normalize(CameraPosition - Input.Pos.xyz);
						float3 Direction = normalize(RotatedBillboardAxis);
						float3 Up = normalize(cross(Direction, ToCameraDir));
						WorldPos = Input.Pos.xyz + Offset.x * Direction + Offset.y * Up;
					}
				#else
					float3 WorldPos = Input.Pos.xyz + Offset;
				#endif

				Out.Pos = FixProjectionAndMul( ViewProjectionMatrix, float4( WorldPos, 1.0f ) );
				Out.UV0 = CalcCellUV( float2(Input.UV0.x, 1.0f - Input.UV0.y), FlipbookDimensions.x, FlipbookDimensions.y, Input.Pos.w );
				Out.Color = Input.Color;
				Out.WorldSpacePos = WorldPos;
				
				return Out;
			}
		]]
	}
}


PixelShader =
{
	TextureSampler DiffuseMap
	{
		Ref = PdxTexture0
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}

	MainCode PixelColor
	{
		Input = "VS_OUTPUT_PARTICLE"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				return Input.Color;
			}
		]]
	}
}