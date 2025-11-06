Code
[[
// --------------------------------------------------------------
// A collection of constants that can be used to tweak the shaders
// To update: run "reloadfx all"
// --------------------------------------------------------------

static const float TWO_PI = 6.28318530718f;
static const float HALF_PI = 1.57079632679f;

// --------------------------------------------------------------
// ------------------    Lighting       -------------------------
// --------------------------------------------------------------
static const float SHADOW_AMBIENT_MIN_FACTOR = 0.0;
static const float SHADOW_AMBIENT_MAX_FACTOR = 0.3;


// --------------------------------------------------------------
// ------------------    TERRAIN        -------------------------
// --------------------------------------------------------------
static const float COLORMAP_OVERLAY_STRENGTH 	= 1.00f;


// --------------------------------------------------------------
// ------------------    WATER          -------------------------
// --------------------------------------------------------------
static const float  WATER_TIME_SCALE	= 1.0f / 50.0f;


// --------------------------------------------------------------
// ------------------    HOVERING       -------------------------
// --------------------------------------------------------------
static const float3  HOVER_COLOR	= float3(1.0f, 0.772f, 0.341f);
static const float HOVER_INTENSITY = 10.0f;
static const float HOVER_FRESNEL_BIAS = 0.004f;
static const float HOVER_FRESNEL_POWER = 8.0f;
]]
