Includes = {
	"pdxmesh_vfx.fxh"
	"cw/pdxmesh.fxh"
	"standardfuncsgfx.fxh"
	"cw/camera.fxh"
	"cw/pdxgui.fxh"
	"cw/utility.fxh"
	"jomini/jomini_mapobject.fxh"
}

VertexStruct VS_OUTPUT_PDXMESH_VFX
{
	float4 Position			: PDX_POSITION;
	float3 Normal			: TEXCOORD0;
	float3 Tangent			: TEXCOORD1;
	float3 Bitangent		: TEXCOORD2;
	float2 UV0				: TEXCOORD3;
	float2 UV1				: TEXCOORD4;
	float3 WorldSpacePos	: TEXCOORD5;
	uint InstanceIndex 		: TEXCOORD6;
	float2 UV2				: TEXCOORD7;
};



VertexShader =
{
	Code
	[[
		#define UI_SCREEN_BURN_UV0_MULT float2( 2.4f, 3.1f )
		#define UI_SCREEN_BURN_UV0_SPEED 0.05f
		#define UI_SCREEN_BURN_UV1_SPEED 0.1f

		#define UI_PANNING_TEXTURE_UV0_MULT float2 ( 5.0f, 1.0f )
		#define UI_PANNING_TEXTURE_UV0_SPEED float2 ( 0.0f, 0.4f )

		#define UI_PANNING_TEXTURE_UV2_MULT float2( 3.0f, 0.5f )
		#define UI_PANNING_TEXTURE_UV2_SPEED float2 ( 0.05f, 0.05f)
	]]
}

PixelShader =
{
	Code
	[[
		#define UV_DIST_STRENGTH 0.1f

		#define LOWER_EDGE_FALLOFF 0.8f
		#define LOWER_EDGE_MULT 1.0f
		#define LOWER_EDGE_CUT 0.1f
		#define LOWER_EDGE_COL_SLIDE 0.1f

		#define UPPER_EDGE_FALLOFF 0.1f
		#define UPPER_EDGE_COL float3( 0.2f, 0.0f, 0.0f )

		#define FINAL_ALPHA_MULT 1.0f
		#define FINAL_COL_MULT 3.0f

		float ApplyOpacity( float BaseAlpha, float2 NoiseCoordinate, in uint InstanceIndex )
		{
		#ifdef JOMINI_MAP_OBJECT
			float Opacity = UnpackAndGetMapObjectOpacity( InstanceIndex );
		#else
			float Opacity = PdxMeshGetOpacity( InstanceIndex );
		#endif
			return PdxMeshApplyOpacity( BaseAlpha, NoiseCoordinate, Opacity );
		}

		float2 ScaleUV( float2 UV, float Scale)
		{
			UV -= 0.5f;
			UV *= Scale;
			UV += 0.5f;
			return UV;
		}
		float4 SampleClampedUV( PdxTextureSampler2D Texture, float2 UV )
		{
			if ( UV.x < 0.0 || UV.x > 1.0 ||
			UV.y < 0.0 || UV.y > 1.0 )
			{
				return vec4( 0.0f );
			}
			return PdxTex2DLod0( Texture, UV );
		}
	]]
}

VertexShader =
{
	Code
	[[
		VS_OUTPUT_PDXMESH_VFX ConvertOutputFromPdxMesh( VS_OUTPUT_PDXMESH In )
		{
			VS_OUTPUT_PDXMESH_VFX Out;

			Out.Position = In.Position;
			Out.Normal = In.Normal;
			Out.Tangent = In.Tangent;
			Out.Bitangent = In.Bitangent;
			Out.UV0 = In.UV0;
			Out.UV1 = In.UV1;
			Out.UV2 = In.UV1;
			Out.WorldSpacePos = In.WorldSpacePos;
			return Out;
		}

		void BillboardMVPMatrix ( inout float4x4 MVPMatrix, in int3 BillboardAxis )
		{
			if(!BillboardAxis.x)
			{
				MVPMatrix[0][0] = 1.0f;
				MVPMatrix[0][1] = 0.0f;
				MVPMatrix[0][2] = 0.0f;
			}

			if(!BillboardAxis.y)
			{
				MVPMatrix[1][0] = 0.0f;
				MVPMatrix[1][1] = 1.0f;
				MVPMatrix[1][2] = 0.0f;
			}

			if(!BillboardAxis.z)
			{
				MVPMatrix[2][0] = 0.0f;
				MVPMatrix[2][1] = 0.0f;
				MVPMatrix[2][2] = 1.0f;
			}
		}

		void ApplyJointAnimation (
			inout VS_OUTPUT_PDXMESH_VFX Out,
			in VS_INPUT_PDXMESHSTANDARD Input,
			in float4x4 WorldMatrix)
		{
			#ifdef PDX_MESH_SKINNED
				float4 Position = float4( Input.Position.xyz, 1.0 );
				float3 BaseNormal = Input.Normal;
				float3 BaseTangent = Input.Tangent.xyz;

				float4 SkinnedPosition = vec4( 0.0 );
				float3 SkinnedNormal = vec3( 0.0 );
				float3 SkinnedTangent = vec3( 0.0 );
				float3 SkinnedBitangent = vec3( 0.0 );

				uint JointsInstanceIndex = Input.InstanceIndices.x;

				float4 Weights = float4( Input.BoneWeight.xyz, 1.0 - Input.BoneWeight.x - Input.BoneWeight.y - Input.BoneWeight.z );

				for( int i = 0; i < PDXMESH_MAX_INFLUENCE; ++i )
				{
					uint BoneIndex = Input.BoneIndex[i];
					uint OffsetIndex = BoneIndex + JointsInstanceIndex;

					float4x4 VertexMatrix = PdxMeshGetJointVertexMatrix( OffsetIndex );
					float3x3 VertexRotationMatrix = CastTo3x3( VertexMatrix );
					float3x3 NormalMatrix = transpose( VertexRotationMatrix );

					SkinnedPosition += mul( VertexMatrix, Position ) * Weights[ i ];

					// TODO [FM]: PSGE-3819 Better skinned normals
					float3 Normal = mul( NormalMatrix, BaseNormal );
					float3 Tangent = mul( NormalMatrix, BaseTangent );
					float3 Bitangent = cross( Normal, Tangent ) * Input.Tangent.w;
					Bitangent = normalize( Bitangent );

					SkinnedNormal += Normal * Weights[i];
					SkinnedTangent += Tangent * Weights[i];
					SkinnedBitangent += Bitangent * Weights[i];
				}

				Out.Normal = normalize( mul( CastTo3x3(WorldMatrix), normalize( SkinnedNormal ) ) );
				Out.Tangent = normalize( mul( CastTo3x3(WorldMatrix), normalize( SkinnedTangent ) ) );
				Out.Bitangent = normalize( mul( CastTo3x3(WorldMatrix), normalize( SkinnedBitangent ) ) );

				Out.Position = SkinnedPosition;
			#endif
		}

	]]

	MainCode VS_mesh_vfx_standard
	{
		Input = "VS_INPUT_PDXMESHSTANDARD"
		Output = "VS_OUTPUT_PDXMESH_VFX"
		Code
		[[
			PDX_MAIN
			{
				VS_OUTPUT_PDXMESH_VFX Out = ConvertOutputFromPdxMesh( PdxMeshVertexShaderStandard( Input ) );
				Out.InstanceIndex = Input.InstanceIndices.y;

				#ifdef SMOKE_MESH
					#if defined( SWAY_SPEED )
						float SwaySpeed = SWAY_SPEED;
					#else
						float SwaySpeed = 1.0f;
					#endif

					#if defined( SWAY_AMOUNT ) 
						float SwayAmount = SWAY_AMOUNT;
					#else
						float SwayAmount = 0.1f;
					#endif

					float4x4 WorldMatrix = PdxMeshGetWorldMatrix( Input.InstanceIndices.y );
					Out.WorldSpacePos = mul( WorldMatrix, float4( Input.Position.xyz, 1.0f ) ).xyz;

					float HeightFactor = Out.WorldSpacePos.y;
					float Sway = sin( GuiTime * SwaySpeed ) * SwayAmount;
					Out.WorldSpacePos.x += Sway * HeightFactor;
					
					Out.Position = mul( ViewProjectionMatrix, float4( Out.WorldSpacePos, 1.0f ) );
				#endif

				#ifdef BILLBOARD_MESH_SKINNED
					float4x4 WorldMatrix = PdxMeshGetWorldMatrix( Input.InstanceIndices.y );
					float4x4 ProjectionWorldViewMatrix = mul ( ProjectionMatrix, mul ( ViewMatrix, WorldMatrix ) );

					ApplyJointAnimation ( Out, Input, WorldMatrix );
					BillboardMVPMatrix( ProjectionWorldViewMatrix, int3(0, 0, 1) );
					Out.Position = mul(ProjectionWorldViewMatrix, Out.Position);
				#endif

				#ifdef BILLBOARD_MESH
					float4x4 WorldMatrix = PdxMeshGetWorldMatrix( Input.InstanceIndices.y );
					float3 WorldSpacePos = mul( WorldMatrix, float4( float3( 0.0f, 0.0f, 0.0f ), 1.0f ) ).xyz;

					float3 ViewDir = CameraPosition - WorldSpacePos;
					float Angle = atan2( ViewDir.x, ViewDir.z );
					float Cosine = cos( Angle );
					float Sine = sin( Angle );
					float3x3 RotMarix = Create3x3( float3( Cosine, 0, Sine ), float3( 0, 1.0, 0 ), float3( -Sine, 0.0, Cosine ) );

					float4 NewPos = float4( mul( RotMarix, Input.Position.xyz ), 1.0 );
					#ifdef BILLBOARD_OFFSET_DISTANCE
						ViewDir.y = 0.0f;
						ViewDir = normalize(ViewDir);
						NewPos.xyz += -ViewDir * BILLBOARD_OFFSET_DISTANCE;
					#endif
					NewPos = mul( WorldMatrix, NewPos );
					Out.Position = FixProjectionAndMul( ViewProjectionMatrix, NewPos );
				#endif

			#ifdef BILLBOARD_HALO_MESH
				float4x4 WorldMatrix = PdxMeshGetWorldMatrix( Input.InstanceIndices.y );

				// Object pivot world position
				float3 WorldSpacePos = mul( WorldMatrix, float4( 0.0f, 0.0f, 0.0f, 1.0f ) ).xyz;

				// World scale
				float3 Scale = float3(
					length( WorldMatrix[0].xyz ),
					length( WorldMatrix[1].xyz ),
					length( WorldMatrix[2].xyz )
				);

				// Camera direction
				float3 Forward = normalize( CameraPosition - WorldSpacePos );

				// Remove X mirror: revert to original order
				float3 Right = normalize( cross( float3( 0.0f, 1.0f, 0.0f ), Forward ) );
				float3 Up = cross( Forward, Right );

				// Vertex offset relative to pivot (with scale)
				float3 LocalOffset = Input.Position.xyz * Scale;

				// Rotate to face camera
				float3 RotatedOffset = Right * LocalOffset.x + Up * LocalOffset.y + Forward * LocalOffset.z;

				// Return to object origin
				float3 NewWorldPos = WorldSpacePos + RotatedOffset;
				
				// Optional horizontal offset along camera
				#ifdef BILLBOARD_OFFSET_DISTANCE
					float3 HorDir = Forward;
					NewWorldPos += -HorDir * BILLBOARD_OFFSET_DISTANCE;
				#endif
				// Projection
				Out.Position = FixProjectionAndMul( ViewProjectionMatrix, float4( NewWorldPos, 1.0f ) );
			#endif

				#ifdef UI_PANNING_TEXTURE
					Out.UV1 = Input.UV0;

					Out.UV0 *= UI_PANNING_TEXTURE_UV0_MULT;
					Out.UV0  = frac ( GlobalTime * UI_PANNING_TEXTURE_UV2_SPEED );

					Out.UV2 *= UI_PANNING_TEXTURE_UV2_MULT;
					Out.UV2 += frac( GlobalTime * UI_PANNING_TEXTURE_UV2_SPEED );
				#endif

				#ifdef UI_SCREEN_BURN
					Out.UV0 *= UI_SCREEN_BURN_UV0_MULT;
					Out.UV1 = Out.UV0;

					Out.UV0 += vec2( frac( GlobalTime * UI_SCREEN_BURN_UV0_SPEED ) );
					Out.UV1 += vec2( frac( GlobalTime * UI_SCREEN_BURN_UV1_SPEED ) );
				#endif

				return Out;
			}
		]]
	}
}

PixelShader =
{
	MainCode PS_mesh_vfx_head_halo
	{
		Input = "VS_OUTPUT_PDXMESH_VFX"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{
				PS_COLOR_SSAO Out;

				float4 Diffuse = SampleClampedUV( DiffuseMap, ScaleUV( Input.UV0, 1.5f ) );
				
				Diffuse.a = ApplyOpacity( Diffuse.a, Input.Position.xy, Input.InstanceIndex );
				const float HaloScale = 1.1f;
				const float2 UV = Input.UV0 * 2.0f - 1.0f;
				const float CenterLength = length( UV );
				const float Dist = CenterLength * HaloScale ;
				const float Angle = atan2( UV.y, UV.x );

				const float3 HaloColor = float3( 1.0f, 0.5f, 0.08f );
				const float HalfGuiTime = GuiTime * 0.5f;
				const float SinHalfGuiTime = sin( HalfGuiTime );

				const float3 RotationSpeed = float3( GuiTime * 0.0505f, -HalfGuiTime, GuiTime * 0.083f );
				const float3 PeakNumber = float3( 4.0f, 1.0f, 10.0f );
				float3 Rays = abs( cos( ( Angle + RotationSpeed ) * PeakNumber ) );
				Rays = Rays * Rays * Rays;
				Rays.y *= Rays.y * Rays.y;
				// Glow
				const float3 GlowFactor = float3( 1.0f - Dist * 0.8f, 1.0f - Dist * 0.7f, 1.0f - Dist * 0.87f );
				float FadeAnimation = 0.9f + 0.3f * sin( GuiTime * 2.5f );
				float TotalGlow = Rays.x * GlowFactor.x + Rays.y * GlowFactor.y + Rays.z * GlowFactor.z * FadeAnimation;
				TotalGlow *= smoothstep( 0.6f, 1.0f, Dist ) * 0.8f;

				// Ring
				float Ring = smoothstep( 0.695f, 0.905f, Dist ) - smoothstep( 0.8f, 1.4f, Dist );
				Ring *= 0.4f + 0.05f * SinHalfGuiTime;

				float RingScale2 = CenterLength * 1.32f;
				float Ring2 = smoothstep( 0.795f, 0.905f, RingScale2 ) - smoothstep( 0.8f, 1.0f, RingScale2 );
				Ring2 *= 0.9f;

				float HaloEffect = saturate( max( Ring, TotalGlow ) + Ring2 ) * 1.285f;
				Diffuse.rgb = lerp( Diffuse * Diffuse.a, HaloColor, HaloEffect );
				float3 FinalColor = Diffuse.rgb;
				float Mask = smoothstep( 1.0f, 0.6f, CenterLength );

				Out.Color = float4( FinalColor, saturate( Diffuse.a + HaloEffect * 1.2f ) * Mask );
				Out.SSAOColor = float4( 1.0f, 1.0f, 1.0f, Diffuse.a );
				return Out;
			}
		]]
	}
}

