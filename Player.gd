extends Node2D


var main
var player_name
var cards = []
var bid = null
var tricks = 0
var score = 0
var bid_max = 0
var is_dealer = false
var trump_card = null
var first_lead = false
var all_face_up = false
var disabled_bid = null
var disable_bidding = false
var reaction_timer = 0.0


func _ready():
	$DeckBG.set_card(Global.JOKER, false)
	$DeckBG/AnimatedSprite.modulate = Color(0.0, 0.0, 0.0, 1.0)
	for i in range(0, Global.MAX_BID+1):
		get_node("Bid"+str(i)).set_value(i)


func _process(delta):
	reaction_timer -= delta
	if reaction_timer <= 0:
		reaction_timer = 0.0


func setup(main, player_name):
	self.main = main
	self.player_name = player_name
	visible = true
	update()


func set_dealer(is_dealer, trump_card):
	self.is_dealer = is_dealer
	self.trump_card = trump_card
	update()


func set_first_lead(value):
	first_lead = value
	update()


func set_all_face_up(value):
	all_face_up = value
	update()


func round_reset():
	cards = []
	bid = null
	tricks = 0
	update()


func set_bid(amount):
	bid = amount
	disabled_bid = null
	update()


func set_disabled_bid(amount):
	disabled_bid = amount
	update()


func add_trick():
	tricks += 1
	get_parent().dbg(player_name + " tricks = " + str(tricks))
	update()
	

func set_tricks(value):
	tricks = value
	get_parent().dbg(player_name + " tricks = " + str(tricks))
	update()


func set_score(value):
	score = value
	update()


func set_cards(cards):
	self.cards = cards
	for i in range(1, 13+1):
		var c = get_node("Card"+str(i))
		c.set_pending(false)
	update()
	
	
func get_card(card_num):
	return get_node("Card"+str(card_num))


func set_bids(maximum):
	bid_max = maximum
	reset_pending()
	update()
	
	
func reset_pending():
	for i in range(0, bid_max+1):
		var b = get_node("Bid"+str(i))
		b.set_pending(false)
	

func card_played(card):
	cards[cards.find(card)] = null
	update()
   

func update():
	
	# Deck.
	$DealLabel.visible = false
	if is_dealer:
		$Deck.visible = true
		if trump_card == null:
			$DealLabel.visible = true
			$Deck.set_card(Global.JOKER, false)  # Dummy card, face down anyway.
		else:
			$Deck.set_card(trump_card, true, false)  # TODO: Maybe don't highlight the turned up card?
	else:
		$Deck.visible = false
		
	# Cards.
	var i = 0
	for card in cards:
		i += 1
		var is_trump = false if trump_card == null or card == null else (Global.suit(card) in [Global.suit(Global.JOKER), Global.suit(trump_card)])
		get_node("Card"+str(i)).set_card(card, all_face_up, is_trump)
	
	# Bids.
	for i in range(0, Global.MAX_BID+1):
		var b = get_node("Bid"+str(i))
		b.visible = i <= bid_max and cards.size() > 0
		b.modulate.a = 1.0 if (bid == null or bid == i) and disabled_bid != i else 0.1
		
	# Info.
	$Info.text = "%s\n%s/%s\n%s" % [
			player_name.to_upper() if player_name != null else "???", 
			tricks, 
			bid if bid != null else "?", 
			"+"+str(abs(score)) if score > 0 else "-"+str(abs(score)) if score < 0 else "ZERO"
		]
	
	# Tricks.
	for i in range(1, Global.MAX_BID+1):
		get_node("Trick"+str(i)).visible = tricks >= i
	
	# First lead.
	$FirstLead.visible = first_lead


# Functions for aut-playing, getting a bit hacky really..

func try_play_card(num):
	for i in range(1, 13+1):
		var c = get_node("Card"+str(i))
		c.set_pending(i == num and not c.is_pending)
	main.play_card(cards[num-1])
	
	
func get_pending_card():
	for i in range(1, 13+1):
		var c = get_node("Card"+str(i))
		if c.is_pending:
			return c.card
	return null
	
	
func try_bid(num):
	if disable_bidding or get_node("Bid"+str(num)).modulate.a != 1.0:
		return
	for i in range(0, bid_max+1):
		var b = get_node("Bid"+str(i))
		b.set_pending(i == num and not b.is_pending)
	main.place_bid(num)
	
	
func get_pending_bid():
	for i in range(0, bid_max+1):
		var b = get_node("Bid"+str(i))
		if b.is_pending:
			return b.value
	return null


func _on_Deck_pressed(): main.deal_cards()
func _on_Bid0_pressed(): try_bid(0)
func _on_Bid1_pressed(): try_bid(1)
func _on_Bid2_pressed(): try_bid(2)
func _on_Bid3_pressed(): try_bid(3)
func _on_Bid4_pressed(): try_bid(4)
func _on_Bid5_pressed(): try_bid(5)
func _on_Bid6_pressed(): try_bid(6)
func _on_Bid7_pressed(): try_bid(7)
func _on_Bid8_pressed(): try_bid(8)
func _on_Bid9_pressed(): try_bid(9)
func _on_Bid10_pressed(): try_bid(10)
func _on_Bid11_pressed(): try_bid(11)
func _on_Bid12_pressed(): try_bid(12)
func _on_Bid13_pressed(): try_bid(13)
func _on_Card1_pressed(): try_play_card(1)
func _on_Card2_pressed(): try_play_card(2)
func _on_Card3_pressed(): try_play_card(3)
func _on_Card4_pressed(): try_play_card(4)
func _on_Card5_pressed(): try_play_card(5)
func _on_Card6_pressed(): try_play_card(6)
func _on_Card7_pressed(): try_play_card(7)
func _on_Card8_pressed(): try_play_card(8)
func _on_Card9_pressed(): try_play_card(9)
func _on_Card10_pressed(): try_play_card(10)
func _on_Card11_pressed(): try_play_card(11)
func _on_Card12_pressed(): try_play_card(12)
func _on_Card13_pressed(): try_play_card(13)


func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_C:
			_on_PositiveReaction_pressed()
		if event.scancode == KEY_X:
			_on_NeutralReaction_pressed()
		if event.scancode == KEY_Z:
			_on_NegativeReaction_pressed()


func _on_PositiveReaction_pressed():
	if reaction_timer <= 0:
		main.send_reaction(1)
		reaction_timer = 0.1


func _on_NeutralReaction_pressed():
	if reaction_timer <= 0:
		main.send_reaction(0)
		reaction_timer = 0.1


func _on_NegativeReaction_pressed():
	if reaction_timer <= 0:
		main.send_reaction(-1)
		reaction_timer = 0.1
