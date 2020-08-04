extends Node


signal anim_ready
signal anim_complete(anim)
signal all_anims_complete

# Copied from server.
enum ERRORS {
	NO_ERROR=0, 
	NOT_PLAYING,
	PLAYERS_FULL, 
	PLAYER_NAME_ALREADY_USED,
	GAME_ALREADY_STARTED,
	NOT_ENOUGH_PLAYERS,
	NOT_READY_FOR_DEALING,
	NOT_IN_GAME,
	PLAYER_NOT_FOUND,
	INCORRECT_PLAYER_TURN,
	INCORRECT_PLAYER_DEAL,
	PLAYER_ALREADY_BID,
	BID_OUT_OF_RANGE,
	BIDS_CANNOT_SUM_TO_CARDS,
	NOT_BIDDING,
	DOES_NOT_HAVE_CARD,
	NOT_FOLLOWING_SUIT,
	TRUMPS_NOT_BROKEN,
}

enum STATE {PRE_GAME=0, DEAL, BID, PLAY, POST_GAME, PAUSED}  # XXX


# HIGH LEVEL PARAMS -- CHANGE BEFORE RELEASING
const DEFAULT_IP_ADDRESS = "35.189.18.88"
#const DEFAULT_IP_ADDRESS = "127.0.0.1"
const OVERRIDE_IP_ADDRESS_LOAD = true
const ESC_QUITS = false
const TEST_BUTTONS = false
# REMEMBER TO UPDATE CREDITS WITH VERSION!

#const ip = "127.0.0.1"
#const ip = "192.168.1.112"
#const ip = "35.189.18.88"

#var host
var server_ip_address = DEFAULT_IP_ADDRESS
var client
const DEFAULT_PORT = 44444


var this_player_name
var this_game_num

var all_players = []  # Names.
var all_opponents = []  # Nodes.

var game_options
var current_scores = {}
var current_score_history = []

var running_time = 0.0

var current_total_bid
var current_num_cards
var current_num_bids
var current_dealer

var err_msg_timer = 0


# -----------------------------------------------------------------------------


func err(func_name, errno):
	var message = "[ERROR] " + func_name + " failed, errno=" + str(errno)
	print(message)
	$Debug.text += message + "\n"


func dbg(text):
	var message = "[DEBUG] " + text
	print(message)
	$Debug.text += message + "\n"
	

#var client
func _ready():
	randomize()
	
	$TestCreate.visible = TEST_BUTTONS
	$TestJoin.visible = TEST_BUTTONS
	$TestStart.visible = TEST_BUTTONS
	
	# Top.
	#$Opponent_21_30_42_50_63_70_84/Speech/Pivot.rotation_degrees = 180
	for n in ["Opponent_21_30_42_50_63_70_84", "Opponent_20_30_40_50_60_70_83", "Opponent_20_30_40_50_60_70_85", "Opponent_20_30_40_52_60_73_80", "Opponent_20_30_40_53_60_74_80"]:
		get_node(n+"/Speech/Pivot").rotation_degrees = 180        
	
	# Left.
	#$Opponent_20_31_41_51_60_70_80/Speech.rotation_degrees = -90
	#$Opponent_20_31_41_51_60_70_80/Speech.position.y -= 40
	for n in ["Opponent_20_31_41_51_60_70_80", "Opponent_20_30_40_50_61_71_81", "Opponent_20_30_40_50_62_72_82"]:
		get_node(n+"/Speech").rotation_degrees = -90
		get_node(n+"/Speech").position.y -= 40
	
	# Right.
	#$Opponent_20_32_43_54_60_70_80/Speech.rotation_degrees = -270
	#$Opponent_20_32_43_54_60_70_80/Speech.position.y -= 40
	#$Opponent_20_32_43_54_60_70_80/Speech/Sprite.scale = Vector2(-$Opponent_20_32_43_54_60_70_80/Speech/Sprite.scale.x, $Opponent_20_32_43_54_60_70_80/Speech/Sprite.scale.y)
	#$Opponent_20_32_43_54_60_70_80/Speech/Pivot.position.x -= 5
	for n in ["Opponent_20_32_43_54_60_70_80", "Opponent_20_30_40_50_64_75_86", "Opponent_20_30_40_50_65_76_87"]:
		get_node(n+"/Speech").rotation_degrees = -270
		get_node(n+"/Speech").position.y -= 40
		get_node(n+"/Speech/Sprite").scale = Vector2(-get_node(n+"/Speech/Sprite").scale.x, get_node(n+"/Speech/Sprite").scale.y)
		get_node(n+"/Speech/Pivot").position.x -= 5
	
	
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
	#host = NetworkedMultiplayerENet.new()
	#var file = File.new()
	#if not OVERRIDE_IP_ADDRESS_LOAD and file.open("user://ipaddress.txt", File.READ) == 0:
	#    var ip = file.get_line()
	#    file.close()
	#    connect_to_server(ip)
	#else:
	#    connect_to_server(DEFAULT_IP_ADDRESS)
	# Perhaps try Google hosting instead.
	#https://www.reddit.com/r/godot/comments/bux2hs/how_to_use_godots_high_level_multiplayer_api_with/
	client = WebSocketClient.new()
	var file = File.new()
	if not OVERRIDE_IP_ADDRESS_LOAD and file.open("user://ipaddress.txt", File.READ) == 0:
		var ip = file.get_line()
		file.close()
		connect_to_server(ip)
	else:
		connect_to_server(DEFAULT_IP_ADDRESS)
	
	$Dealing/Cards/Card.set_card(Global.JOKER, false, false)
	$Dealing/Cards/Trump.set_card(Global.JOKER, false, false)
	$Dealing/Cards/Deck.set_card(Global.JOKER, false, false)


func connect_to_server(ip_address):
	if client.get_connected_host():
		dbg("Already connected")
		return
	$Menu/Group/IPText.text = ip_address
	$Menu.set_server_status("CONNECTING")
	var url = "ws://" + ip_address + ":" + str(DEFAULT_PORT)
	var error = client.connect_to_url(url, PoolStringArray(), true)
	dbg("connect_to_url returned " + str(error))
	if error == 0:
		server_ip_address = ip_address
		get_tree().set_network_peer(client)
#    #host.close_connection()
#    var err = host.create_client(ip_address, DEFAULT_PORT)
#    if err == OK:
#        get_tree().set_network_peer(host)
#        server_ip_address = ip_address
#    elif err == ERR_CANT_CREATE:
#        set_server_status("FAILED")    
#    else:
#        dbg("Unknown connect_to_server error: " + str(err))
		

func _connected_fail():
	dbg("Failed to connect to server " + str(server_ip_address))
	$Menu.set_server_status("FAILED")
	

func _connected_ok():
	dbg("Successfully connected to server " + str(server_ip_address))
	$Menu.set_server_status("CONNECTED")
	var file = File.new()
	file.open("user://ipaddress.txt", File.WRITE)
	file.store_line(server_ip_address)
	file.close()
   

func _server_disconnected():
	dbg("Disconnected from server.")
	$Menu.set_server_status("DISCONNECTED")


func set_lobby_status(status):
	$Menu/Group/LobbyStatus.text = status
	
	
func set_game_status(status):
	$Menu/Group/GameStatus.text = status


func _process(delta):
	if ESC_QUITS and Input.is_action_just_pressed("ui_cancel"): 
		get_tree().quit()
	if (client.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTED ||
		client.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTING):
			client.poll()
	
	running_time += delta
	if running_time < 2.0:
		#$Title.text = "      \n    "
		$Title.text = ""
	elif running_time < 2.6:
		#$Title.text = "HELL  \n    "  # nbsp
		$Title.text = "_          HELL                 _"
	elif running_time < 3.2:
		#$Title.text = "HELL &\n    "
		$Title.text = "_          HELL &               _"
	else:
		#$Title.text = "HELL &\nBACK"
		$Title.text = "_          HELL & BACK          _"
		
	process_anims()
	
	$Arrow/Pivot/Pivot.global_rotation = 0
	
	err_msg_timer -= delta
	if err_msg_timer < 0:
		err_msg_timer = 0
		$ErrMsg.text = ""
		$ErrMsg.visible = false
	

func _unhandled_key_input(event):
	if event.scancode == KEY_M and event.is_pressed():
		$Menu/Group.visible = not $Menu/Group.visible
		$Menu/Group/Credits.visible = false
	#if event.scancode == KEY_D and event.is_pressed():
	#    $Debug.visible = not $Debug.visible


func find_player_node(player_name):
	var who
	if player_name == this_player_name:
		who = $PlayerSelf
	else:
		for opp in all_opponents:
			if player_name == opp.player_name:
				who = opp
	return who


func set_err_msg(text):
	$ErrMsg.text = text
	$ErrMsg.visible = true
	err_msg_timer = 2.0
	

# -----------------------------------------------------------------------------


func list_games():
	rpc_id(1, "list_games")


puppet func games_listed(games):
	dbg("Games list: " + str(games))
	# TODO: Maintain selection.
	$Menu/Group/GamesList.clear()
	for game in games:
		var num = game[0]
		var players = game[1]
		var lost = game[2]
		var string = "#%s [" % [num]
		for p in players:
			string += p + ("?" if p in lost else "") + " "
		string = string.strip_edges() + "]"
		$Menu/Group/GamesList.add_item(string)
		#$Menu/Group/GamesList.add_item("#%s %s" % game)


func create_game(playing_for, hell_round):
	var options = {
			"playing_for": playing_for,
			"hell_round": hell_round,
		}
	rpc_id(1, "create_game", options)
	
	
puppet func game_created(num):
	dbg("Created game " + str(num))


func join_game(game_num, player_name):
	rpc_id(1, "join_game", game_num, player_name)
	
	
puppet func game_joined(errno, num, name):
	if errno: 
		err("game_joined", errno)
		set_lobby_status("")
		match errno:
			ERRORS.PLAYERS_FULL: set_game_status("Maximum players reached")
			ERRORS.PLAYER_NAME_ALREADY_USED: set_game_status("Player name already used")
			ERRORS.GAME_ALREADY_STARTED: set_game_status("Game already started")
			_: set_game_status("Join error " + str(errno))
		return
	dbg("Joined as player " + name)
	set_game_status("In game #" + str(num) + " as \"" + name + "\"")
	this_player_name = name
	this_game_num = num
	$Menu.set_joined_game()


puppet func lost_player(game_num, player_name):
	if game_num == this_game_num:
		set_game_status("Lost player " + player_name)
		$Menu/Group.visible = true


puppet func game_cancelled(game_num):
	if game_num == this_game_num:
		set_game_status("Game cancelled")
		$Menu.set_left_game()
		$Menu/Group.visible = true
		

func leave_game():
	rpc_id(1, "leave_game", this_game_num, this_player_name)
	$Menu.set_left_game()
	set_game_status("Left game " + str(this_game_num))
	this_game_num = null
	this_player_name = null


func start_game():
	if this_game_num != null:
		rpc_id(1, "start_game", this_game_num)
	else:
		set_game_status("Have not joined a game")


puppet func resuming_game(data):
	dbg("Resuming game")
	$Menu/Group.visible = false
	#dbg(str(data))
	setup_players(data["players"])
	$PlayerSelf.set_cards(data["cards"])
	$PlayerSelf.set_all_face_up(true)
	game_options = data["options"]
	current_scores = data["player_score"]
	current_score_history = data["score_history"]
	current_total_bid = 0
	current_num_bids = 0
	for bid in data["player_bids"].values():
		if bid != null:
			current_total_bid += bid
			current_num_bids += 1
	current_num_cards = data["current_num_cards"]
	current_dealer = data["current_dealer"]
	for p in [$PlayerSelf]+all_opponents:
		p.set_bid(data["player_bids"].get(p.player_name, null))
		p.set_dealer(current_dealer == p.player_name, data["trump_card"])
	for player_card in data["current_hand"]:
		var card = player_card[1]
		var is_trump = Global.suit(card) in [Global.suit(Global.JOKER), Global.suit($PlayerSelf.trump_card)] 
		find_player_node(player_card[0]).get_node("Card").set_card(card, true, is_trump)
	$Menu.update_scorepad()
	
	
func setup_players(players):
	
	all_opponents = []
	var all_possible_opponents = [
		"Opponent_21_30_42_50_63_70_84", 
		"Opponent_20_30_40_50_60_70_83", 
		"Opponent_20_30_40_50_60_70_85",
		"Opponent_20_30_40_52_60_73_80",
		"Opponent_20_30_40_53_60_74_80",
		"Opponent_20_31_41_51_60_70_80", 
		"Opponent_20_30_40_50_61_71_81", 
		"Opponent_20_30_40_50_62_72_82",
		"Opponent_20_32_43_54_60_70_80",
		"Opponent_20_30_40_50_64_75_86",
		"Opponent_20_30_40_50_65_76_87",
	]
	var num_players = players.size()
	for opp_num in range(1, num_players+1):
		for opp_node_name in all_possible_opponents:
			if (str(num_players)+str(opp_num)) in opp_node_name:
				all_opponents.append(get_node(opp_node_name))
	assert(all_opponents.size()+1 == num_players)
	
	$PlayerSelf.setup(self, this_player_name)
	
	all_players = [this_player_name]
	var i = 0
	var index = (players.find(this_player_name) + 1) % players.size()
	while players[index] != this_player_name:
		all_players.append(players[index])
		all_opponents[i].setup(players[index])
		index = (index + 1) % players.size()
		i += 1
	dbg("Setting all players to " + str(all_players))
	

puppet func game_started(errno, game_num, players, options):
	if errno: 
		err("game_started", errno)
		set_game_status("Start error " + str(errno))
		return
	dbg("Game started with " + str(players) + " options = " + str(options))
	
	game_options = options
	
	$Menu/Group.visible = false
	$Menu.set_playing_game()
	
	setup_players(players)
	
	current_scores = {}
	for p in all_players:
		current_scores[p] = 0
	
	$Title.modulate.a = 0.125
	$PlayingFor.modulate.a = 0.125
	$PlayingFor.text = game_options["playing_for"]
	
	current_score_history = []
	$Menu.update_scorepad()
	
	$PlayerSelf.set_score(0)
	$PlayerSelf.round_reset()
	for opp in all_opponents:
		opp.set_score(0)
		opp.round_reset()


puppet func waiting_for(player_name, state):
	dbg("Waiting (" + str(state) + ") on player " + player_name)
	
	# Queue.
	var anim = queue_anim("wait")
	yield(anim, "ready")
	
	# Start.
	$Arrow.visible = true
	$Arrow/Pivot/Pivot/Label.text = ["", "DEAL", "BID", "PLAY", ""][state]
	if state == STATE.DEAL:
		$Status.text = ""
	if state == STATE.PLAY:
		if current_total_bid < current_num_cards:
			$BidStatus.text = str(abs(current_total_bid - current_num_cards)) + " UNDER"
			#$BidStatus.add_color_override("font_color", Color(0,0.5,0,1))  # TODO: Not happy with these colors.
			#$BidStatus.add_color_override("font_color", Color(0.6,0.6,0.6,1))
		else:
			$BidStatus.text = str(abs(current_total_bid - current_num_cards)) + " OVER"
			#$BidStatus.add_color_override("font_color", Color(0.6,0.6,0.6,1))
	if state == STATE.BID and current_num_bids == all_players.size()-1 and player_name == this_player_name:
		$PlayerSelf.set_disabled_bid(current_num_cards - current_total_bid)
	
	# Middle.
	var tween = $Tween
	var initial = $Arrow.global_rotation
	$Arrow.look_at(find_player_node(player_name).position)
	var final = $Arrow.global_rotation
	while final < initial: final += 2*PI
	#$Arrow/Pivot/Pivot.rotation = -$Arrow.rotation - PI/2
	tween.interpolate_property($Arrow, "global_rotation", initial, final, 0.375, Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	
	# Finish.
	if state == STATE.DEAL: # Not sure how to structure this yet.
		$PlayerSelf.set_dealer(player_name == this_player_name, null)
		for opp in all_opponents:
			opp.set_dealer(player_name == opp.player_name, null)
		var first_lead = all_players[(all_players.find(player_name)+1) % all_players.size()]
		for p in [$PlayerSelf]+all_opponents:
			p.set_first_lead(p.player_name == first_lead)
	if state != STATE.DEAL and state != STATE.BID:
		for p in [$PlayerSelf]+all_opponents:
			p.set_first_lead(false)
	anim.complete()
	
	# TODO: Perhaps poll this from _process instead.
	# Auto play.  
	if state == STATE.PLAY and player_name == this_player_name:
		dbg("Attempting to auto-play")
		var card = $PlayerSelf.get_pending_card()
		if card != null:
			dbg("Auto-playing " + str(card))
			play_card(card)
	if state == STATE.BID and player_name == this_player_name:
		dbg("Attempting to auto-bid")
		var bid = $PlayerSelf.get_pending_bid()
		if bid != null:
			dbg("Auto-bidding " + str(bid))
			place_bid(bid)
	

func deal_cards():
	if anim_playing != null: return  # TODO: Temp.
	rpc_id(1, "deal_cards", this_game_num, this_player_name)
	
puppet func cards_dealt(errno, cards, trump_card, dealer):
	if errno: err("cards_dealt", errno) ; if errno: return # XXX
	dbg("Dealt cards " + str(cards) + ", trump " + str(trump_card) + ", dealt by " + dealer)
	
	# Queue.
	var anim = queue_anim("deal")
	yield(anim, "ready")
	
	# Start.
	$PlayerSelf.set_all_face_up(false)
	$PlayerSelf.set_bids(0)
	if dealer == this_player_name:
		$PlayerSelf.set_dealer(false, trump_card)
	$Dealing.visible = true
	$Arrow.visible = false
	var dealer_offset = all_players.find(dealer)
	var dealer_deck = find_player_node(dealer).get_node("Deck")
	var tween = $Dealing/Tween
	var card = $Dealing/Cards/Card
	var trump = $Dealing/Cards/Trump
	var deck = $Dealing/Cards/Deck
	for n in [card, trump, deck]:
		n.visible = true
		n.position = Vector2(0,0)
		n.scale = Vector2(1,1)
		n.rotation = 0.0
		n.set_card(Global.JOKER, false, false)
	
	# Middle - get deck.
	$ShuffleSound.play()
	tween.interpolate_property($Dealing, "modulate:a", 0, 1, 0.7, Tween.TRANS_QUART, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	
	# Middle - deal cards.
	var ds = 0
	for card_num in range(cards.size()):
		for player_offset in range(all_players.size()):
			var player = find_player_node(all_players[(dealer_offset + 1 + player_offset) % all_players.size()])
			var player_card = player.get_card(card_num+1)
			#var time = 0.3 if card_num < 5 else 0.2 if card_num < 10 else 0.15
			#var time = 0.25 - 0.175*card_num/12.0
			var time = 2.0 / (all_players.size() * cards.size())
			if time > 0.3: time = 0.3
			tween.interpolate_property(card, "global_position", deck.global_position, player_card.global_position,      time, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
			tween.interpolate_property(card, "global_rotation", deck.global_rotation, player_card.global_rotation+2*PI, time, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
			tween.interpolate_property(card, "global_scale"   , deck.global_scale,    player_card.global_scale,         time, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
			tween.start()
			get_node("DealSound"+str(ds+1)).play()
			ds = (ds + 1) % 4
			yield(tween, "tween_all_completed")
			player.set_cards(cards.slice(0, card_num))
			if player == $PlayerSelf: player.set_bids(card_num+1)
	
	# Middle - show trump.
	card.visible = false
	trump.set_card(trump_card, false, false)
	tween.interpolate_property(trump, "scale:x", 1, 0, 0.1, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	trump.set_card(trump_card, true, false)
	tween.interpolate_property(trump, "scale:x", 0, 1, 0.1, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	yield(get_tree().create_timer(1.0), "timeout")
	card.visible = false
	deck.visible = false
	tween.interpolate_property(trump, "global_position", trump.global_position, dealer_deck.global_position, 0.8, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.interpolate_property(trump, "global_rotation", trump.global_rotation, dealer_deck.global_rotation, 0.8, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.interpolate_property(trump, "global_scale",    trump.global_scale,    dealer_deck.global_scale,    0.8, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	
	# Finish.
	$PlayerSelf.set_all_face_up(true)
	$Dealing.visible = false
	$Arrow.visible = true
	$PlayerSelf.disable_bidding = false
	$PlayerSelf.set_tricks(0)
	$PlayerSelf.set_bids(cards.size())
	$PlayerSelf.set_dealer(dealer == this_player_name, trump_card)
	$PlayerSelf.set_cards(cards)
	$PlayerSelf/Card.set_card(null)
	for opp in all_opponents:
		opp.set_dealer(dealer == opp.player_name, trump_card)
		opp.set_num_cards(cards.size())
		opp.set_tricks(0)
		opp.get_node("Card").set_card(null)
	current_num_cards = cards.size()
	current_num_bids = 0
	current_total_bid = 0
	current_dealer = dealer
	$Status.text = "TOTAL BID: 0/"+str(current_num_cards)
	#$Status.add_color_override("font_color", Color(1,1,1,1))
	anim.complete()
	

func place_bid(amount):
	dbg("Placing bid " + str(amount))
	if anim_playing != null: return  # TODO: Temp.
	rpc_id(1, "place_bid", this_game_num, this_player_name, amount)

puppet func bid_placed(errno, player_name, amount):
	if errno: 
		err("bid_placed", errno)
		match errno:
			ERRORS.NOT_PLAYING: pass
			ERRORS.INCORRECT_PLAYER_TURN: pass
			ERRORS.NOT_BIDDING: pass
			ERRORS.BIDS_CANNOT_SUM_TO_CARDS: set_err_msg("Invalid bid!")
			_: set_err_msg("Unexpected error " + str(errno))
		return 
	dbg("Bid placed " + str(amount) + " for " + player_name)
	
	# Queue.
	var anim = queue_anim("bid")
	yield(anim, "ready")
	
	# Start.
	var player = find_player_node(player_name)
	var bidding = $Bidding
	var tween = $Tween
		
	# Middle.
	if player_name == this_player_name:
		player.set_bid(amount)  # Looks better to immediately display bid when self player.
		$PlayerSelf.disable_bidding = true
		$PlayerSelf.reset_pending()
	$BidSound.play()
	bidding.set_value(amount)
	bidding.visible = true
	bidding.global_position = $Center.global_position
	tween.interpolate_property(bidding, "global_scale", Vector2(0, 0), Vector2(2.1, 2.1), 1.0, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	if player_name == this_player_name:
		tween.interpolate_property(bidding, "global_position", bidding.global_position, $PlayerSelf/OffScreen.global_position, 0.6, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		tween.interpolate_property(bidding, "global_scale",    bidding.global_scale,    Vector2(1,1),                          0.6, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		tween.start()
		yield(tween, "tween_all_completed")
	else:
		var bid_node = player.get_node("Bid")
		tween.interpolate_property(bidding, "global_position", bidding.global_position, bid_node.global_position, 0.6, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		tween.interpolate_property(bidding, "global_scale",    bidding.global_scale,    bid_node.global_scale,    0.6, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		tween.start()
		yield(tween, "tween_all_completed")
	
	# Finish.
	player.set_bid(amount)
	bidding.visible = false
	current_num_bids += 1
	current_total_bid += amount
	$Status.text = "TOTAL BID: " + str(current_total_bid) + "/"+str(current_num_cards)
	anim.complete()


func play_card(card):
	dbg("Playing card " + card)
	if anim_playing != null: return  # TODO: Temp.
	rpc_id(1, "play_card", this_game_num, this_player_name, card)
	
puppet func card_played(errno, player_name, card, first_card):
	if errno: 
		err("card_played", errno)
		match errno:
			ERRORS.NOT_PLAYING: pass
			ERRORS.INCORRECT_PLAYER_TURN: pass
			ERRORS.DOES_NOT_HAVE_CARD: pass  # This shouldn't happen.. but have observed it once. See video from SMG.
			ERRORS.NOT_FOLLOWING_SUIT: set_err_msg("Must follow suit!")
			ERRORS.TRUMPS_NOT_BROKEN: set_err_msg("Trumps not broken!")
			_: set_err_msg("Unexpected error " + str(errno))
		return
	dbg("Card played " + str(card) + " for " + player_name + " (first card = " + str(first_card) + ")")
	
	# Queue.
	var anim = queue_anim("play")
	yield(anim, "ready")
	
	# Start.
	var is_trump = Global.suit(card) in [Global.suit(Global.JOKER), Global.suit($PlayerSelf.trump_card)] 
	var player = find_player_node(player_name)
	var card_node = player.get_node("Card")
	player.card_played(card)
	$PlayingCard.set_card(card, true, is_trump)
	$PlayingCard.global_position = player.get_node("OffScreen").global_position
	$PlayingCard.global_rotation = card_node.global_rotation

	# Middle.
	get_node("CardSound" + str(randi()%4+1)).play()
	var tween = $Tween
	tween.interpolate_property($PlayingCard, "global_position", player.get_node("OffScreen").global_position, card_node.global_position,        0.4, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.interpolate_property($PlayingCard, "global_rotation", card_node.global_rotation,                    card_node.global_rotation + 2*PI, 0.4, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	
	# Finish.
#    if first_card:  # TODO: Might not need this once animations can show the results.
#        $PlayerSelf/Card.set_card(null)
#        for opp in all_opponents:
#            opp.get_node("Card").set_card(null)
#    if player_name == this_player_name:
#        $PlayerSelf.card_played(card)
#        $PlayerSelf/Card.set_card(card, true, is_trump)
#    for opp in all_opponents:
#        if player_name == opp.player_name:
#            opp.card_played(card)
#            opp.get_node("Card").set_card(card, true, is_trump)
	card_node.set_card(card, true, is_trump)
	$PlayingCard.visible = false
	anim.complete()


puppet func trick_completed(winner):
	dbg("Trick completed winner " + winner)
	
	# Queue.
	var anim = queue_anim("trick")
	yield(anim, "ready")
	
	# Start.
	var player = find_player_node(winner)
	var restore = []
	var all = [$PlayerSelf] + all_opponents
	for p in all:
		restore.append([p.get_node("Card").global_position, p.get_node("Card").global_rotation, p.get_node("Card").global_scale])
			
	# Middle.
	yield(get_tree().create_timer(1.2), "timeout")
	var tween = $Tween
	for p in all:
		var c = p.get_node("Card")
		tween.interpolate_property(c, "global_position", c.global_position, player.get_node("OffScreen").global_position, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		#tween.interpolate_property(c, "global_rotation", c.global_rotation, player.get_node("OffScreen").global_rotation, 0.5, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	player.add_trick()
	yield(get_tree().create_timer(0.2), "timeout")
	
	# Finish.
	var i = 0
	for p in all:
		var c = p.get_node("Card")
		c.set_card(null)
		c.global_position = restore[i][0]
		c.global_rotation = restore[i][1]
		c.global_scale = restore[i][2]
		i += 1
	anim.complete()


puppet func round_completed(this_scores, scores, score_history):
	dbg("Round completed, scores: " + str(scores))
	
	# Queue.
	var anim = queue_anim("deal")
	yield(anim, "ready")
	
	# Start.
	$Status.text = ""
	$BidStatus.text = ""
	var tween = $Tween
	$HitMiss.visible = true
	$HitMiss/Label.text = ""
	
	# Middle.
	var count = 0
	var index = all_players.find(current_dealer)
	while count < all_players.size():
		index = (index + 1) % all_players.size()
		var player = all_players[index]
		count += 1
		
		$HitMiss.position = $Center.position
		$HitMiss.scale = Vector2(0.01,0.01)
		$HitMiss/Label.text = ("+" if this_scores[player] > 0 else "-") + str(abs(this_scores[player]))
		$HitMiss/Label.add_color_override("font_color", Color(1,1,1,1) if this_scores[player] > 0 else Color(1,0,0,1))
		tween.interpolate_property($HitMiss, "scale", Vector2(0.01,0.01), Vector2(1,1), 0.25, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
		tween.start()
		yield(tween, "tween_all_completed")
		($HitSound if this_scores[player] > 0 else $MissSound).play()
		var player_node = find_player_node(player)
		tween.interpolate_property($HitMiss, "global_position", $HitMiss.global_position, player_node.get_node("OffScreen").global_position, 0.75, Tween.TRANS_CUBIC, Tween.EASE_IN)
		tween.start()
		yield(tween, "tween_all_completed")
		player_node.set_score(scores[player])
	
	# Finish.
	$HitMiss.visible = false
	$PlayerSelf.set_score(scores[this_player_name])
	$PlayerSelf.round_reset()
	for player_name in scores.keys():
		for opp in all_opponents:
			if player_name == opp.player_name:
				opp.set_score(scores[player_name])
				opp.round_reset()
	current_scores = scores
	current_score_history = score_history
	$Menu.update_scorepad()
	anim.complete()


puppet func game_completed(score_history):
	dbg("Game complete")
	
	# Queue.
	var anim = queue_anim("deal")
	yield(anim, "ready")
	
	# Start.
	
	# Middle.
	yield(get_tree().create_timer(2.5), "timeout")
	
	# Finish.
	$PlayerSelf.visible = false
	for opp in all_opponents:
		opp.visible = false
	$Arrow.visible = false
	$Menu/Group.visible = true
	current_score_history = score_history
	$Menu.update_scorepad()
	anim.complete()


func send_reaction(value):
	rpc_id(1, "send_reaction", this_game_num, this_player_name, value)
	
	
puppet func receive_reaction(player_name, text):
	dbg("Player " + player_name + " reacted with " + text)
	find_player_node(player_name).get_node("Speech").show_reaction(text)


# -----------------------------------------------------------------------------


#class Animations:
#    signal all_complete
#    var anims = []
#    func queue(anim, time):
#        anims.push_back(anim)
#    func process():
#        pass


var anims = []
var anim_playing = null

func queue_anim(name):
	var anim = Anim.new(self, name)
	anims.push_back(anim)
	return anim

func process_anims():
	if anim_playing == null and anims.size() > 0:
		var anim = anims.pop_front()
		anim_playing = anim.name
		anim.emit_signal("ready")
	$AnimDebug.text = "playing = " + str(anim_playing) + ", queue = " + str(anims)

class Anim:
	signal ready
	var main
	var name
	func _init(_main, _name):
		main = _main
		name = _name
	func complete():
		main.anim_playing = null
		

# ----- TEST FUNCTIONS -----

func _on_TestCreate_pressed():
	create_game("test", 13)

func _on_TestJoin_pressed():
	join_game(1, "p" + str(randi()%100))

func _on_TestStart_pressed():
	start_game()

# --------------------------


func _on_ArrowButton_pressed():
	# Hacky last minute request to allow this.
	if $Arrow/Pivot/Pivot/Label.text == "DEAL":
		deal_cards()
