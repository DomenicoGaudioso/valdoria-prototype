@tool
extends EditorScript

## Run this from the Godot editor: File > Run (or Ctrl+Shift+X)
## Creates all scenes with proper texture references.

func _run() -> void:
	print("=== ELDRATH - Editor Build ===")
	_create_all()
	print("=== COMPLETATO. Apri scenes/main/Main.tscn e premi F5 ===")


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = parent


func _fix_owners(node: Node) -> void:
	for c in node.get_children():
		_fix_owners(c)
		c.owner = node


func _save(node: Node, path: String) -> void:
	_fix_owners(node)
	var packed := PackedScene.new()
	packed.pack(node)
	ResourceSaver.save(packed, path)
	print("  OK: " + path.get_file())


func _create_all() -> void:
	print("[Player]"); _player()
	print("[Enemy]"); _enemy()
	print("[DropItem]"); _dropitem()
	print("[World]"); _world()
	print("[GameUI]"); _gameui()
	print("[Main]"); _main()


func _player() -> void:
	var r := CharacterBody2D.new(); r.name = "Player"

	var cs := CollisionShape2D.new(); cs.name = "CollisionShape2D"
	var c := CircleShape2D.new(); c.radius = 22.0; cs.shape = c; _add(r, cs)

	var sh := Sprite2D.new(); sh.name = "Shadow"
	sh.texture = load("res://assets/placeholders/shadow.png")
	sh.position = Vector2(0, 32); sh.z_index = -1; sh.scale = Vector2(1.3, 1.3); _add(r, sh)

	var sp := Sprite2D.new(); sp.name = "Sprite2D"
	sp.texture = load("res://assets/placeholders/player.png")
	sp.position = Vector2(0, -35); sp.scale = Vector2(1.3, 1.3)
	sp.region_enabled = true; sp.region_rect = Rect2(0, 0, 91, 161); _add(r, sp)

	var aa := Area2D.new(); aa.name = "AttackArea"; _add(r, aa)
	var ac := CollisionShape2D.new(); ac.name = "CollisionShape2D"
	var ac2 := CircleShape2D.new(); ac2.radius = 60.0; ac.shape = ac2; _add(aa, ac)

	var ap := AnimationPlayer.new(); ap.name = "AnimationPlayer"; _add(r, ap)

	r.set_script(load("res://scripts/player/Player.gd"))
	_save(r, "res://scenes/player/Player.tscn")


func _enemy() -> void:
	var r := CharacterBody2D.new(); r.name = "Enemy"

	var cs := CollisionShape2D.new(); cs.name = "CollisionShape2D"
	var c := CircleShape2D.new(); c.radius = 20.0; cs.shape = c; _add(r, cs)

	var sh := Sprite2D.new(); sh.name = "Shadow"
	sh.texture = load("res://assets/placeholders/shadow.png")
	sh.position = Vector2(0, 35); sh.z_index = -1; sh.scale = Vector2(1.3, 1.3); _add(r, sh)

	var sp := Sprite2D.new(); sp.name = "Sprite2D"
	sp.texture = load("res://assets/placeholders/enemy.png")
	sp.position = Vector2(0, -40); sp.scale = Vector2(1.3, 1.3)
	sp.region_enabled = true; sp.region_rect = Rect2(805, 367, 162, 170); _add(r, sp)

	var da := Area2D.new(); da.name = "DetectionArea"; da.collision_mask = 2; _add(r, da)
	var dc := CollisionShape2D.new(); dc.name = "CollisionShape2D"
	var dc2 := CircleShape2D.new(); dc2.radius = 220.0; dc.shape = dc2; _add(da, dc)

	var ap := AnimationPlayer.new(); ap.name = "AnimationPlayer"; _add(r, ap)

	r.set_script(load("res://scripts/enemies/Enemy.gd"))
	_save(r, "res://scenes/enemies/Enemy.tscn")


func _dropitem() -> void:
	var r := Area2D.new(); r.name = "DroppedItem"; r.collision_mask = 2

	var cs := CollisionShape2D.new(); cs.name = "CollisionShape2D"
	var c := CircleShape2D.new(); c.radius = 22.0; cs.shape = c; _add(r, cs)

	var sp := Sprite2D.new(); sp.name = "Sprite2D"
	sp.texture = load("res://assets/placeholders/sword_icon.png"); sp.scale = Vector2(2, 2); _add(r, sp)

	var lb := Label.new(); lb.name = "Label"
	lb.position = Vector2(-50, -35); lb.scale = Vector2(0.6, 0.6)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 10); _add(r, lb)

	r.set_script(load("res://scripts/items/DroppedItem.gd"))
	_save(r, "res://scenes/items/DroppedItem.tscn")


func _world() -> void:
	var r := Node2D.new(); r.name = "World"
	var terrain := Node2D.new(); terrain.name = "Terrain"; _add(r, terrain)

	# Isometric grassland background
	var g := Sprite2D.new(); g.name = "Ground"
	g.texture = load("res://assets/placeholders/ground.png")
	g.scale = Vector2(0.5, 0.5); g.centered = false; g.z_index = -10; _add(terrain, g)

	# Path overlay
	var p := Sprite2D.new(); p.name = "Path"
	p.texture = load("res://assets/placeholders/path.png")
	p.scale = Vector2(20, 2); p.position = Vector2(0, 500); p.centered = false; p.z_index = -9; _add(terrain, p)

	# Rocks
	var rt := load("res://assets/placeholders/rock.png")
	var rocks := [["Rock1",Vector2(300,600),Vector2(2.5,2.5)],["Rock2",Vector2(900,300),Vector2(2,2)],["Rock3",Vector2(600,700),Vector2(1.8,1.8)],["Rock4",Vector2(1200,550),Vector2(2.5,2.5)],["Rock5",Vector2(200,350),Vector2(1.5,1.5)],["Rock6",Vector2(1100,800),Vector2(2,2)]]
	for rk in rocks:
		var s := Sprite2D.new(); s.name = rk[0]; s.texture = rt; s.position = rk[1]; s.scale = rk[2]; _add(terrain, s)

	var ut := load("res://assets/placeholders/ruin.png")
	var ruins := [["Ruin1",Vector2(950,680),Vector2(3.5,3)],["Ruin2",Vector2(1250,450),Vector2(3,2.5)],["Ruin3",Vector2(400,800),Vector2(2.5,2)]]
	for rk in ruins:
		var s := Sprite2D.new(); s.name = rk[0]; s.texture = ut; s.position = rk[1]; s.scale = rk[2]; _add(terrain, s)

	r.set_script(load("res://scripts/world/World.gd"))
	r.set("enemy_scene", load("res://scenes/enemies/Enemy.tscn"))
	r.set("enemy_spawns", [Vector2(800, 400), Vector2(1100, 650)])
	r.set("dropped_item_scene", load("res://scenes/items/DroppedItem.tscn"))

	_save(r, "res://scenes/world/World.tscn")


func _gameui() -> void:
	var r := CanvasLayer.new(); r.name = "GameUI"

	# Top-Left: Health
	var mtl := MarginContainer.new(); mtl.name = "MarginContainer"
	mtl.anchor_left = 0.0; mtl.anchor_top = 0.0; mtl.anchor_right = 0.0; mtl.anchor_bottom = 0.0
	mtl.offset_right = 320.0; mtl.offset_bottom = 90.0
	mtl.add_theme_constant_override("margin_left", 16); mtl.add_theme_constant_override("margin_top", 16)
	_add(r, mtl)

	var vbox := VBoxContainer.new(); vbox.name = "VBoxContainer"; _add(mtl, vbox)
	var t1 := Label.new(); t1.name = "TitleLabel"; t1.text = "VITA"
	t1.add_theme_color_override("font_color", Color(0.8,0.8,0.8)); t1.add_theme_font_size_override("font_size", 16)
	_add(vbox, t1)

	var hb := ProgressBar.new(); hb.name = "HealthBar"; hb.unique_name_in_owner = true
	hb.min_value = 0.0; hb.max_value = 100.0; hb.value = 100.0
	hb.custom_minimum_size = Vector2(250, 28); hb.show_percentage = false; _add(vbox, hb)

	var hl := Label.new(); hl.name = "HealthLabel"; hl.unique_name_in_owner = true; hl.text = "100 / 100"
	hl.add_theme_color_override("font_color", Color(1,0.3,0.3)); hl.add_theme_font_size_override("font_size", 13)
	_add(vbox, hl)

	# Bottom-Right: Buttons
	var mbr := MarginContainer.new(); mbr.name = "ButtonContainer"
	mbr.anchor_left = 1.0; mbr.anchor_top = 1.0; mbr.anchor_right = 1.0; mbr.anchor_bottom = 1.0
	mbr.offset_left = -260.0; mbr.offset_top = -130.0
	mbr.add_theme_constant_override("margin_right", 16); mbr.add_theme_constant_override("margin_bottom", 16)
	_add(r, mbr)

	var hbx := HBoxContainer.new(); hbx.name = "HBoxContainer"
	hbx.add_theme_constant_override("separation", 12); _add(mbr, hbx)

	var invb := Button.new(); invb.name = "InventoryButton"; invb.unique_name_in_owner = true
	invb.text = "Zaino (I)"; invb.custom_minimum_size = Vector2(130, 56); _add(hbx, invb)

	var atkb := Button.new(); atkb.name = "AttackButton"; atkb.unique_name_in_owner = true
	atkb.text = "Attacca"; atkb.custom_minimum_size = Vector2(110, 56); _add(hbx, atkb)

	# Inventory Panel (center, hidden)
	var pnl := Panel.new(); pnl.name = "InventoryPanel"; pnl.unique_name_in_owner = true
	pnl.anchor_left = 0.5; pnl.anchor_top = 0.5; pnl.anchor_right = 0.5; pnl.anchor_bottom = 0.5
	pnl.offset_left = -240.0; pnl.offset_top = -320.0; pnl.offset_right = 240.0; pnl.offset_bottom = 320.0; pnl.visible = false

	var ps := StyleBoxFlat.new(); ps.bg_color = Color(0.06,0.06,0.1,0.95)
	ps.border_width_left = 2; ps.border_width_right = 2; ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.border_color = Color(0.45,0.38,0.25,1.0)
	pnl.add_theme_stylebox_override("panel", ps); _add(r, pnl)

	var pvb := VBoxContainer.new(); pvb.name = "VBoxContainer"
	pvb.anchor_left = 0.05; pvb.anchor_top = 0.05; pvb.anchor_right = 0.95; pvb.anchor_bottom = 0.95; _add(pnl, pvb)

	var itl := Label.new(); itl.name = "Title"; itl.text = "INVENTARIO"
	itl.add_theme_color_override("font_color", Color(0.85,0.78,0.55)); itl.add_theme_font_size_override("font_size", 20)
	itl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _add(pvb, itl)

	var sc := ScrollContainer.new(); sc.name = "ScrollContainer"; sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; _add(pvb, sc)
	var il := VBoxContainer.new(); il.name = "InventoryList"; il.unique_name_in_owner = true
	il.add_theme_constant_override("separation", 4); _add(sc, il)

	var cb := Button.new(); cb.name = "CloseButton"; cb.text = "Chiudi"; cb.custom_minimum_size = Vector2(0, 44); _add(pvb, cb)

	var dbg := Label.new(); dbg.name = "DebugLabel"; dbg.unique_name_in_owner = true
	dbg.anchor_left = 0.0; dbg.anchor_bottom = 1.0; dbg.offset_left = 16.0; dbg.offset_bottom = -90.0
	dbg.modulate = Color.YELLOW; dbg.visible = false; _add(r, dbg)

	r.set_script(load("res://scripts/ui/GameUI.gd"))
	_save(r, "res://scenes/ui/GameUI.tscn")


func _main() -> void:
	var r := Node2D.new(); r.name = "Main"

	var w: Node = load("res://scenes/world/World.tscn").instantiate(); w.name = "World"; _add(r, w)

	var pl: Node2D = load("res://scenes/player/Player.tscn").instantiate(); pl.name = "Player"
	pl.position = Vector2(640, 400); _add(r, pl)

	var cam := Camera2D.new(); cam.name = "Camera2D"; cam.enabled = true
	cam.position_smoothing_enabled = true; cam.position_smoothing_speed = 5.0
	cam.zoom = Vector2(0.85, 0.85); _add(pl, cam)

	var di := Node2D.new(); di.name = "DroppedItems"; _add(r, di)

	var ui: CanvasLayer = load("res://scenes/ui/GameUI.tscn").instantiate(); ui.name = "GameUI"
	ui.set("player", pl); _add(r, ui)

	_save(r, "res://scenes/main/Main.tscn")
