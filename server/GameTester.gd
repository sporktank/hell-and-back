extends Node2D

var game_class = preload("res://Game.gd")
var game = null


func _ready():
    for p in range(1,4):
        get_node("P"+str(p)).get_node('Deal').connect("pressed", self, "_on_P"+str(p)+"Deal_pressed")
        get_node("P"+str(p)).get_node('Bid0').connect("pressed", self, "_on_P"+str(p)+"Bid0_pressed")
        get_node("P"+str(p)).get_node('Bid1').connect("pressed", self, "_on_P"+str(p)+"Bid1_pressed")
        get_node("P"+str(p)).get_node('Bid2').connect("pressed", self, "_on_P"+str(p)+"Bid2_pressed")
        get_node("P"+str(p)).get_node('Bid3').connect("pressed", self, "_on_P"+str(p)+"Bid3_pressed")
        get_node("P"+str(p)).get_node('Card1').connect("pressed", self, "_on_P"+str(p)+"Card1_pressed")
        get_node("P"+str(p)).get_node('Card2').connect("pressed", self, "_on_P"+str(p)+"Card2_pressed")
        get_node("P"+str(p)).get_node('Card3').connect("pressed", self, "_on_P"+str(p)+"Card3_pressed")


func update():
    $Trump.text = str(game.get_trump_card())
    $P1/Bid.text = str(game.get_bid("MJS"))
    $P1/Cards.text = str(game.get_cards("MJS"))
    $P1/Tricks.text = str(game.get_tricks("MJS"))
    $P2/Bid.text = str(game.get_bid("LLXU"))
    $P2/Cards.text = str(game.get_cards("LLXU"))
    $P2/Tricks.text = str(game.get_tricks("LLXU"))
    $P3/Bid.text = str(game.get_bid("NPS"))
    $P3/Cards.text = str(game.get_cards("NPS"))
    $P3/Tricks.text = str(game.get_tricks("NPS"))
    $Hand.text = str(game.get_current_hand())
    $P1/Name.text = "WAITING" if game.is_waiting_on("MJS") else ""
    $P2/Name.text = "WAITING" if game.is_waiting_on("LLXU") else ""
    $P3/Name.text = "WAITING" if game.is_waiting_on("NPS") else ""
    $Rounds.text = str(game.get_round()) + "--" + str(game.remaining_rounds)
    $State.text = str(game.get_state_string())
    $P1/Score.text = str(game.get_score("MJS"))
    $P2/Score.text = str(game.get_score("LLXU"))
    $P3/Score.text = str(game.get_score("NPS"))
    print(game)
    

func _on_Create_pressed():
    game = game_class.new(1, 3, 3)
    game.connect("changed", self, "update")
    update()
    

func _on_AddMJS_pressed():
    print(game.add_player("MJS"))


func _on_AddLLXU_pressed():
    print(game.add_player("LLXU"))


func _on_AddNPS_pressed():
    print(game.add_player("NPS"))


func _on_Start_pressed():
    print(game.start_game())


# ---------- PLAYER 1 ----------

func _on_P1Deal_pressed():
    print(game.deal_cards("MJS"))
    

func _on_P1Bid0_pressed():
    print(game.place_bid("MJS", 0))
    

func _on_P1Bid1_pressed():
    print(game.place_bid("MJS", 1))


func _on_P1Bid2_pressed():
    print(game.place_bid("MJS", 2))


func _on_P1Bid3_pressed():
    print(game.place_bid("MJS", 3))


func _on_P1Card1_pressed():
    print(game.play_card("MJS", game.get_cards("MJS")[0]))


func _on_P1Card2_pressed():
    print(game.play_card("MJS", game.get_cards("MJS")[1]))


func _on_P1Card3_pressed():
    print(game.play_card("MJS", game.get_cards("MJS")[2]))


# ---------- PLAYER 2 ----------

func _on_P2Deal_pressed():
    print(game.deal_cards("LLXU"))
    

func _on_P2Bid0_pressed():
    print(game.place_bid("LLXU", 0))
    

func _on_P2Bid1_pressed():
    print(game.place_bid("LLXU", 1))


func _on_P2Bid2_pressed():
    print(game.place_bid("LLXU", 2))


func _on_P2Bid3_pressed():
    print(game.place_bid("LLXU", 3))


func _on_P2Card1_pressed():
    print(game.play_card("LLXU", game.get_cards("LLXU")[0]))


func _on_P2Card2_pressed():
    print(game.play_card("LLXU", game.get_cards("LLXU")[1]))


func _on_P2Card3_pressed():
    print(game.play_card("LLXU", game.get_cards("LLXU")[2]))
    
    
# ---------- PLAYER 3 ----------

func _on_P3Deal_pressed():
    print(game.deal_cards("NPS"))
    

func _on_P3Bid0_pressed():
    print(game.place_bid("NPS", 0))
    

func _on_P3Bid1_pressed():
    print(game.place_bid("NPS", 1))


func _on_P3Bid2_pressed():
    print(game.place_bid("NPS", 2))


func _on_P3Bid3_pressed():
    print(game.place_bid("NPS", 3))


func _on_P3Card1_pressed():
    print(game.play_card("NPS", game.get_cards("NPS")[0]))


func _on_P3Card2_pressed():
    print(game.play_card("NPS", game.get_cards("NPS")[1]))


func _on_P3Card3_pressed():
    print(game.play_card("NPS", game.get_cards("NPS")[2]))

