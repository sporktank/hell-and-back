extends Node2D


var timeout = 0.0


func show_reaction(text):
    visible = true
    scale = Vector2(0,0)
    $Tween.stop_all()
    $Tween2.stop_all()
    $Pivot/Label.text = text
    $Tween.interpolate_property(self, "scale", scale, Vector2(1,1), 0.4, Tween.TRANS_BACK, Tween.EASE_OUT)
    $Tween.start()
    timeout = 2.0
    #yield($Tween, "tween_all_completed")
    #yield(get_tree().create_timer(2.0), "timeout")
    ##timeout = 2.0
    #$Tween.interpolate_property(self, "scale", scale, Vector2(0,0), 0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT)
    #$Tween.start()
    #yield($Tween, "tween_all_completed")
    #visible = false


func _process(delta):
    if timeout > 0:
        #if not $Tween.is_active():
        timeout -= delta
        if timeout < 0:
            timeout = 0.0
            $Tween2.interpolate_property(self, "scale", scale, Vector2(0,0), 0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT)
            $Tween2.start()
