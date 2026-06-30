#!/usr/bin/env python3
"""Extract a cohesive block of functions from a GDScript monolith into a new
RefCounted builder module that delegates shared utilities/state to a host node.

Usage:
  python build_module.py <source.gd> <out_module.gd> <ClassName> <func1> [func2 ...]

The extracted functions are copied verbatim, then these host-shared identifiers
are prefixed with `host.` (word-boundary safe): _iso, _get_tex, _load_tex,
_add_sprite, _tinted_color, _profile_color, _profile_float, _stable_map_noise,
_get_map_visual_profile, _is_real_city, _is_endless_map_id, _get_endless_variant,
_world_node, _current_map_id, _current_map, _current_portal_depth, _osm_cache,
and the bare `create_tween` call.

Finally the same functions are removed from <source.gd>.
"""
import sys
import re

# Identifiers that remain on the host node: prefix with `host.` in extracted code.
HOST_IDS = [
	# longer tokens first to be safe (word boundaries make order irrelevant, but keep tidy)
	"_get_map_visual_profile",
	"_stable_map_noise",
	"_is_endless_map_id",
	"_get_endless_variant",
	"_get_endless_map_id",
	"_get_portal_type_for_map",
	"_is_real_city",
	"_profile_color",
	"_profile_float",
	"_current_portal_depth",
	"_current_map_id",
	"_current_map",
	"_world_node",
	"_player_node",
	"_tileset_type",
	"_portals",
	"_tinted_color",
	"_load_tex",
	"_get_tex",
	"_add_sprite",
	"_osm_cache",
	"_iso",
]

DEF_RE = re.compile(r'^(func |static func |var |const |@export |@onready |# ====)')
FUNC_HEADER = re.compile(r'^(static )?func\s+(\w+)\s*\(')


def find_function_body(lines, name):
	"""Return (start_idx, end_idx) of a top-level function, end exclusive.
	end_idx is the index of the next top-level definition or len(lines)."""
	for i, line in enumerate(lines):
		m = FUNC_HEADER.match(line)
		if m and m.group(2) == name:
			j = i + 1
			while j < len(lines) and not DEF_RE.match(lines[j]):
				j += 1
			return i, j
	return None


def transform(text):
	# create_tween() -> host.create_tween()
	text = re.sub(r'(?<![A-Za-z0-9_])create_tween\(', 'host.create_tween(', text)
	for ident in HOST_IDS:
		pat = r'(?<![A-Za-z0-9_])' + re.escape(ident) + r'(?![A-Za-z0-9_])'
		text = re.sub(pat, 'host.' + ident, text)
	return text


def main():
	src_path = sys.argv[1]
	out_path = sys.argv[2]
	class_name = sys.argv[3]
	names = sys.argv[4:]

	with open(src_path, 'r', encoding='utf-8', newline='') as f:
		lines = f.readlines()

	# Collect function bodies (preserve order of appearance in source).
	bodies = []
	for name in names:
		span = find_function_body(lines, name)
		if span is None:
			print('NOT FOUND:', name)
			return 2
		start, end = span
		bodies.append((name, ''.join(lines[start:end])))

	# Build module file.
	out = []
	out.append('class_name %s\n' % class_name)
	out.append('extends RefCounted\n\n')
	out.append('## %s — estratto da GameBootstrap. Stato/utility condivise restano nell\'host.\n\n' % class_name)
	out.append('var host: Node\n\n\n')
	out.append('func _init(h: Node = null) -> void:\n')
	out.append('\thost = h\n\n\n')
	for name, body in bodies:
		transformed = transform(body)
		out.append(transformed)
		# Ensure a blank line separator between functions.
		if not transformed.endswith('\n\n'):
			out.append('\n')

	with open(out_path, 'w', encoding='utf-8', newline='') as f:
		f.writelines(out)

	# Remove the same functions from source.
	out_lines = []
	i = 0
	n = len(lines)
	removed = set()
	nameset = set(names)
	while i < n:
		line = lines[i]
		m = FUNC_HEADER.match(line)
		if m and m.group(2) in nameset:
			removed.add(m.group(2))
			i += 1
			while i < n and not DEF_RE.match(lines[i]):
				i += 1
			while out_lines and out_lines[-1].strip() == '':
				out_lines.pop()
			if i < n and out_lines and out_lines[-1].strip() != '':
				out_lines.append('\n')
			continue
		out_lines.append(line)
		i += 1

	with open(src_path, 'w', encoding='utf-8', newline='') as f:
		f.writelines(out_lines)

	missing = nameset - removed
	print('Extracted %d functions into %s' % (len(removed), out_path))
	if missing:
		print('NOT FOUND in source removal:', ', '.join(sorted(missing)))
		return 2
	return 0


if __name__ == '__main__':
	sys.exit(main())
