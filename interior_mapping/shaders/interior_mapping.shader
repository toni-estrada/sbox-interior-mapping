
HEADER
{
	Description = "Interior Mapping Shader";
	Version = 1;
}

FEATURES
{
	#include "common/features.hlsl"
}

MODES
{
	VrForward();
	Depth(); 
	ToolsVis( S_MODE_TOOLS_VIS );
	ToolsShadingComplexity("tools_shading_complexity.shader");
	ToolsWireframe("vr_tools_wireframe.shader"); 
}

COMMON
{
	
	#include "common/shared.hlsl"
	#include "procedural.hlsl"

	#define CUSTOM_MATERIAL_INPUTS
}

struct VertexInput
{
	#include "common/vertexinput.hlsl"
};

struct PixelInput
{
	#include "common/pixelinput.hlsl"
	float3 vPositionOs : TEXCOORD14;
};

VS
{
	#include "common/vertex.hlsl"

	PixelInput MainVs( VertexInput v )
	{
		PixelInput i = ProcessVertex( v );
		i.vPositionOs = v.vPositionOs.xyz;
		

		return FinalizeVertex( i );
	}
}

PS
{
	#include "common/pixel.hlsl"
	
	SamplerState g_sSampler0 < Filter( ANISO ); AddressU( WRAP ); AddressV( WRAP ); >;
	CreateInputTextureCube( RoomCubemap, Srgb, 8, "None", "_color", "Room Cubemap,0/,0/0", Default4( 1.00, 1.00, 1.00, 1.00 ) );
	TextureCube g_tRoomCubemap < Channel( RGBA, Box( RoomCubemap ), Srgb ); OutputFormat( DXT5 ); SrgbRead( True ); >;
	
	//UI Elements
	float g_flTiling < UiType( Slider ); UiStep( 1 ); UiGroup( "Room Cubemap,1/Room Tiling,1/1" ); Default1( 1 ); Range1( 1, 128 ); >;
	float g_flDepthValue < UiType( Slider ); UiGroup( "Room Cubemap,2/Depth Adjustment,2/1" ); Default1( 1 ); Range1( -1, 1 ); >;
	float g_flFlipX < UiType( Slider ); UiStep(2); UiGroup( "Room Cubemap,3/Cubemap Image Adjustment,3/2" ); Default1( 1 ); Range1( -1, 1 ); >;
	float g_flFlipY < UiType( Slider ); UiStep(2); UiGroup( "Room Cubemap,3/Cubemap Image Adjustment,3/3" ); Default1( -1 ); Range1( -1, 1 ); >;
	float g_flFlipZ < UiType( Slider ); UiStep(2); UiGroup( "Room Cubemap,3/Cubemap Image Adjustment,3/4" ); Default1( 1 ); Range1( -1, 1 ); >;

	float4 MainPs( PixelInput i ) : SV_Target0
	{
		Material m;
		m.Albedo = float3( 1, 1, 1 );
		m.Normal = TransformNormal( i, float3( 0, 0, 1 ) );
		m.Roughness = 1;
		m.Metalness = 0;
		m.AmbientOcclusion = 1;
		m.TintMask = 1;
		m.Opacity = 1;
		m.Emission = float3( 0, 0, 0 );
		m.Transmission = 0;
		
		// Gets the view direction in tangent space.
		// Thank you Alex from Facepuch for the code.
		float3 vPositionWs = i.vPositionWithOffsetWs.xyz + g_vHighPrecisionLightingOffsetWs.xyz;
		float3 vCameraToPositionDirWs = CalculateCameraToPositionDirWs( vPositionWs.xyz );
		float3 vNormalWs = normalize( i.vNormalWs.xyz );
		float3 vTangentUWs = i.vTangentUWs.xyz;
		float3 vTangentVWs = i.vTangentVWs.xyz;
		float3 vTangentViewVector = Vec3WsToTs( vCameraToPositionDirWs.xyz, vNormalWs.xyz, vTangentUWs.xyz, vTangentVWs.xyz );

		//Interior Mapping Code
		float3 vInverseTanViewDir = 1 / vTangentViewVector;
		float2 vUV = i.vTextureCoords.xy * g_flTiling;
		float2 vUVPos = ((frac(vUV)*2)-1);
		float3 vInteriorBBox = float3(vUVPos.x, vUVPos.y, g_flDepthValue); 
		float3 vKValue = abs(vInverseTanViewDir) - (vInverseTanViewDir * vInteriorBBox);
		float flKMinValue = min(min( vKValue.x, vKValue.y), vKValue.z);
		float3 vCubeImgControl = float3(g_flFlipX, g_flFlipY, g_flFlipZ);
		float3 vCubemapViewDir = ((vTangentViewVector * flKMinValue) + vInteriorBBox) * vCubeImgControl;
		float4 vInteriorMapping = TexCubeS( g_tRoomCubemap, g_sSampler0, vCubemapViewDir.xyz); //zyx adjusts the Cubemap's Rotation 

		m.Emission = vInteriorMapping.xyz;
		m.Opacity = 1;
		m.Roughness = 0;
		m.Metalness = 1;
		m.AmbientOcclusion = 0;
		
		m.AmbientOcclusion = saturate( m.AmbientOcclusion );
		m.Roughness = saturate( m.Roughness );
		m.Metalness = saturate( m.Metalness );
		m.Opacity = saturate( m.Opacity );
		
		#if S_MODE_TOOLS_VIS
                m.Albedo = m.Emission;
                m.Emission = 0;
            #endif

		return ShadingModelStandard::Shade( i, m );
	}
}
