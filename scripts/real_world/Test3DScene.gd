extends Node3D

func _ready() -> void:
	print("=== Test3DScene ready ===")

	# Camera
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(0, 30, 25)
	cam.rotation_degrees = Vector3(-45, 0, 0)
	cam.current = true
	add_child(cam)

	# Light
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.position = Vector3(10, 20, 0)
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.shadow_enabled = true
	add_child(light)

	# Environment
	var env_node := WorldEnvironment.new()
	env_node.name = "Env"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.12, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.3)
	env_node.environment = env
	add_child(env_node)

	# Ground plane
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(60, 60)
	ground.position = Vector3(0, 0, 0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.2, 0.4, 0.15)
	ground.material_override = ground_mat
	add_child(ground)

	# 3 colored building cubes
	var boxes = [
		{"pos": Vector3(-8, 5, -6), "size": Vector3(3, 10, 3), "color": Color(0.7, 0.2, 0.1)},
		{"pos": Vector3(0, 7.5, 4), "size": Vector3(3, 15, 3), "color": Color(0.6, 0.4, 0.15)},
		{"pos": Vector3(7, 4, -2), "size": Vector3(3, 8, 3), "color": Color(0.4, 0.3, 0.55)},
	]

	for b in boxes:
		var box := MeshInstance3D.new()
		box.name = "Building"
		var bm := BoxMesh.new()
		bm.size = b["size"]
		box.mesh = bm
		box.position = b["pos"]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = b["color"]
		box.material_override = mat
		add_child(box)

	# Label
	var label := Label3D.new()
	label.name = "Label"
	label.text = "3D TEST — 3 edifici + terreno"
	label.position = Vector3(0, 20, 0)
	label.font_size = 48
	label.modulate = Color.WHITE
	add_child(label)

	print("=== Scene ready — 3 buildings on green ground ===")
