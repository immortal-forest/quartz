-- quartz: window border colours from the wallpaper, written by matugen. Do not
-- edit: ~/.config/matugen/templates/quartz-hyprland.lua is the source.
-- Two colours each: hypr/quartz.lua draws them as a 45° gradient.
return {
	active = { "rgba({{colors.primary.default.hex_stripped}}ee)", "rgba({{colors.tertiary.default.hex_stripped}}ee)" },
	inactive = { "rgba({{colors.outline_variant.default.hex_stripped}}aa)", "rgba({{colors.surface_container_high.default.hex_stripped}}aa)" },
}
