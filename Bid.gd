extends Node2D


signal pressed


var value
var is_pending = false


func set_pending(value):
    is_pending = value
    update()


func set_value(value):
    self.value = value
    self.is_pending = false
    update()


func update():
    $Pivot/Label.text = str(value) if value != null else "?"
    visible = false if value == null or value < 0 else true
    $Pivot.position.y = -15*int(is_pending)


func _on_Button_pressed():
    emit_signal("pressed")
