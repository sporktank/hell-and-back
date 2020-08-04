extends Node2D


signal pressed


var card
var face_up
var is_trump
var is_pending = false


func _ready():
	set_card(null)


func set_pending(value):
	is_pending = value
	update_sprite()


func set_card(card, face_up=true, is_trump=false):
	self.card = card
	self.face_up = face_up
	self.is_trump = is_trump
	update_sprite()


func update_sprite():
	if card == null:
		visible = false
		return
	visible = true
	var frame
	if face_up:
		if card == Global.JOKER:
			frame = 53
		else:
			frame = 1 + Global.SUITS.find(Global.suit(card))*13 + Global.fval(card)
	else:
		frame = 0
	$AnimatedSprite.set_frame(frame)
	modulate.r = 0.7 if is_trump and face_up else 1.0
	modulate.g = 0.7 if is_trump and face_up else 1.0
	modulate.b = 0.8 if is_trump and face_up else 1.0
	$AnimatedSprite.position.y = -15*int(is_pending)


func _on_Button_pressed():
	emit_signal("pressed")
