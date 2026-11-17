Includes = {
	"cw/camera.fxh"
	"standardfuncsgfx.fxh"
}

Code
[[
	static const float TRADE_ROUTE_EDIT_MODE_ALPHA_SCALE = 0.375f;
	static const float TRADE_ROUTE_EDIT_MODE_GREY_SCALE = 0.2f;
	static const float TRADE_ROUTE_ZOOMED_IN_ALPHA_SCALE = 0.15f;
	static const float TRADE_ROUTE_ZOOMED_IN_ALPHA_MIN_HEIGHT = 0.0f;
	static const float TRADE_ROUTE_ZOOMED_IN_ALPHA_MAX_HEIGHT = 150.0f;
	static const float3 TRADE_ROUTE_DISTRIBUTION_COLOR = float3( 1.0f, 0.78f, 0.22f );
	static const float3 COLOR_COMPENSATION = float3( 1.07f, 1.04f, 1.10f );

	float3 ApplyGoodCategoryColor( float3 Color, float3 PrimaryGoodCategoryColor )
	{
		Color *= pow( PrimaryGoodCategoryColor, 2.2f );
		Color *= COLOR_COMPENSATION;
		return Color;
	}

	float ApplyPlannerModeAlpha( float Alpha, float IsConfirmedRoute, float RouteEditModeAlphaScale )
	{
		return lerp( Alpha, Alpha * RouteEditModeAlphaScale, ( _IsRouteEditMode * IsConfirmedRoute ) );
	}

	float3 ApplyPlannerModeGreyOut( float3 Color, float IsConfirmedRoute )
	{
		const float3 RouteLuminance = vec3( dot( Color, float3( 0.299f, 0.587f, 0.114f ) ) );
		return lerp( Color,
					 RouteLuminance * TRADE_ROUTE_EDIT_MODE_GREY_SCALE,
					 _IsRouteEditMode * IsConfirmedRoute );
	}

	float GetZoomFadeAlpha()
	{
		const float ZoomFadeFactor = smoothstep( TRADE_ROUTE_ZOOMED_IN_ALPHA_MIN_HEIGHT, TRADE_ROUTE_ZOOMED_IN_ALPHA_MAX_HEIGHT, CameraPosition.y );
		const float ZoomedInAlphaScale = lerp( TRADE_ROUTE_ZOOMED_IN_ALPHA_SCALE, 1.0f, _StartColorOverlayHeightBlend );
		return lerp( ZoomFadeFactor * ZoomedInAlphaScale, 1.0f, _IsRouteEditMode );
	}

	float3 ApplyHighlightPulse( float3 Color, float IsHighlighted )
	{
		const float HighlightPulse = sin( GlobalTime * 4.5f );
		const float HighlightBrightness = lerp( 1.0f, 1.0f + 0.5f * HighlightPulse, IsHighlighted );
		return Color * HighlightBrightness;
	}
]]
