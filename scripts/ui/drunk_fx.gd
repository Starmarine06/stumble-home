class_name DrunkFx
extends CanvasLayer
## Full-screen wobble, blur, double vision and blackouts, scaled by drunk level.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float drunk : hint_range(0.0, 1.0) = 0.8;
uniform float t = 0.0;
uniform float blackout = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv += vec2(sin(uv.y * 8.0 + t * 1.7), cos(uv.x * 7.0 + t * 1.3)) * 0.012 * drunk;
	vec3 sharp = textureLod(screen_tex, uv, 0.0).rgb;
	vec2 off = vec2(sin(t * 0.9), cos(t * 0.7)) * 0.02 * drunk;
	vec3 ghost = textureLod(screen_tex, uv + off, 0.0).rgb;
	vec3 blur = textureLod(screen_tex, uv, 2.5 * drunk).rgb;
	vec3 col = mix(sharp, blur, 0.5 * drunk);
	col = mix(col, ghost, 0.35 * drunk);
	float vig = smoothstep(0.9, 0.3, length(SCREEN_UV - 0.5));
	col *= mix(1.0, vig, 0.6 * drunk);
	col *= (1.0 - blackout);
	COLOR = vec4(col, 1.0);
}
"""

var drunk := 0.8
var blackout := 0.0

var _mat := ShaderMaterial.new()
var _t := 0.0


func _ready() -> void:
	layer = 5
	var shader := Shader.new()
	shader.code = SHADER
	_mat.shader = shader
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _mat
	add_child(rect)


func _process(delta: float) -> void:
	_t += delta
	_mat.set_shader_parameter("drunk", drunk)
	_mat.set_shader_parameter("t", _t)
	_mat.set_shader_parameter("blackout", blackout)
