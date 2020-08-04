extends Reference


signal changed # TODO: Remove this eventually.

#signal player_added(name)
signal game_started(players, options)
signal waiting_for(name, state)
signal resuming_game

signal cards_dealt
signal bid_placed(name, amount)
signal card_played(name, card, first_card)
signal trick_completed(winner)
signal round_completed(this_scores, scores, score_history)
signal game_completed(score_history)


enum STATE {PRE_GAME=0, DEAL, BID, PLAY, POST_GAME, PAUSED}

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

const MAX_PLAYERS_PER_GAME = 8

const SUITS = ['s','c','d','h']
const FACES = ['2','3','4','5','6','7','8','9','t','j','q','k','a']
const JOKER = 'xx'

const DEFAULT_OPTIONS = {
		"playing_for": "¿playing for?",
		"hell_round": 13,
		"bowers": false,
		"fair_cards": false,
		"blind_scoring": false,
	}


var state = STATE.PRE_GAME
var game_num = -1
var num_players = -1
var players = []
var current_num_cards = -1
var remaining_rounds = []
var options
var hell_round
var player_cards = {}
var player_bids = {}
var player_tricks = {}
var player_score = {}
var score_history = []
var trump_card = ''
var lead_card = null
var trumps_broken = false
var current_dealer = ''
var current_player_turn = ''
var current_hand = []  # Safer to not use dictionary -- not sure about ordering.
var lost_players = []
var resume_state
var last_touch


func _init(game_num, options):
	randomize()
	self.game_num = game_num
	self.options = options
	restart()


func restart():
	last_touch = OS.get_ticks_msec()
	current_num_cards = -1
	player_cards = {}
	player_bids = {}
	player_tricks = {}
	player_score = {}
	score_history = []
	trump_card = ''
	lead_card = null
	trumps_broken = false
	current_dealer = ''
	current_player_turn = ''
	current_hand = []  # Safer to not use dictionary -- not sure about ordering.
	
	for key in DEFAULT_OPTIONS:
		if not (key in self.options.keys()) or not self.options[key]:
			self.options[key] = DEFAULT_OPTIONS[key]
	hell_round = int(options['hell_round'])
	remaining_rounds = []
	for r in range(1, hell_round+1):
		remaining_rounds.append(r)
	for r in range(hell_round-1, 0, -1):
		remaining_rounds.append(r)
	

func _to_string():
	return "Game(game_num=%d, state=%s, players=%s, trump=%s, cards=%s, dealer=%s, current=%s, round=%s)" % [
		game_num, state, players, trump_card, player_cards, current_dealer, current_player_turn, remaining_rounds]


func get_trump_card(): return trump_card
func get_cards(name): return player_cards.get(name, null)
func get_bid(name): return player_bids.get(name, null)
func get_tricks(name): return player_tricks.get(name, null)
func get_score(name): return player_score.get(name, null)
func get_round(): return current_num_cards
func get_current_hand(): return current_hand.duplicate()
func get_current_player(): return current_player_turn
func get_current_dealer(): return current_dealer
func get_state(): return state
func get_state_string():
	match state:
		STATE.PRE_GAME: return 'pre-game'
		STATE.DEAL: return 'deal'
		STATE.BID: return 'bid'
		STATE.PLAY: return 'play'
		STATE.POST_GAME: return 'post-game'


func is_paused():
	return state == STATE.PAUSED
	
	
func resume():
	state = resume_state
	last_touch = OS.get_ticks_msec()
	emit_signal("waiting_for", current_player_turn, state)


func pause_game(lost_player):
	if state != STATE.PAUSED:
		resume_state = state
	state = STATE.PAUSED
	lost_players.append(lost_player)


func is_joinable(): 
	return state in [STATE.PRE_GAME, STATE.PAUSED] and players.size() <= MAX_PLAYERS_PER_GAME


func is_waiting_on(name):
	return (state == STATE.DEAL and name == current_dealer) or (state in [STATE.BID, STATE.PLAY] and name == current_player_turn)


func _get_new_deck():
	var deck = [JOKER]
	#var num_decks = 1 if num_players <= 4 else 2
	var num_decks = 1 if num_players*hell_round <= 52 else 2  # 2020-08-04: Update for 5+ players to play single deck.
	for deck_num in range(num_decks):
		for suit in SUITS:
			for face in FACES:
				deck.append(face+suit)
	deck.shuffle()
	return deck
	
	
func _next_player(after):
	var index = players.find(after)
	return players[(index+1) % num_players]


func _reset_dict(val, copy=false):
	var result = {}
	for p in players:
		result[p] = val if not copy else val.duplicate()
	return result


func _new_hand():
	current_hand.clear()

	
func suit(card): return card.right(1)
func face(card): return card.left(1)
func fval(card): return FACES.find(card.left(1))    
func beats(a, b, l, t):  # a beats b when t trumps and l lead, b played before a
	if a == b:
		return false
	if a == JOKER:
		return true
	if b == JOKER:
		return false
	if suit(a) == suit(t) and suit(b) != suit(t):
		return true
	if suit(a) == suit(t) and suit(b) == suit(t):
		return fval(a) > fval(b)
	if suit(a) != suit(t) and suit(b) == suit(t):
		return false
	if suit(a) == suit(l) and suit(b) != suit(l):
		return true
	if suit(a) == suit(l) and suit(b) == suit(l):
		return fval(a) > fval(b)
	if suit(a) != suit(l) and suit(b) == suit(l):
		return false

		
func _sort_func(a, b, suit_order):
	if a == JOKER:
		return false
	if b == JOKER:
		return true
	if suit(a) == suit(b):
		return fval(a) < fval(b)
	return suit_order.find(suit(a)) < suit_order.find(suit(b))

func sort_func_h(a, b): return _sort_func(a, b, ['s','d','c','h'])
func sort_func_d(a, b): return _sort_func(a, b, ['s','h','c','d'])
func sort_func_c(a, b): return _sort_func(a, b, ['d','s','h','c'])
func sort_func_s(a, b): return _sort_func(a, b, ['d','c','h','s'])
func sort_func_x(a, b): return _sort_func(a, b, ['s','d','c','h'])    


func add_player(name):
	last_touch = OS.get_ticks_msec()
	if state == STATE.PAUSED:
		if name in lost_players:
			lost_players.erase(name)
			#if lost_players.size() == 0:
			#    state = resume_state
			#    emit_signal("resuming_game")
			return 0
	if state != STATE.PRE_GAME:
		return ERRORS.GAME_ALREADY_STARTED
	if players.find(name) != -1:
		return ERRORS.PLAYER_NAME_ALREADY_USED
	if players.size() == MAX_PLAYERS_PER_GAME:
		return ERRORS.PLAYERS_FULL
	players.append(name)
	#emit_signal("player_added", name)
	return 0


func start_game():
	last_touch = OS.get_ticks_msec()
	if state != STATE.PRE_GAME and state != STATE.POST_GAME:
		return ERRORS.GAME_ALREADY_STARTED
	if players.size() <= 1:
		return ERRORS.NOT_ENOUGH_PLAYERS
	if state == STATE.POST_GAME:  # Re-match.
		restart()
	state = STATE.DEAL
	players.shuffle()
	num_players = players.size()
	current_num_cards = remaining_rounds.pop_front()
	current_dealer = players[0]
	current_player_turn = players[1]
	player_bids = _reset_dict(null)
	player_tricks = _reset_dict(0)
	player_cards = _reset_dict([], true)
	player_score = _reset_dict(0)
	_new_hand()
	#emit_signal("changed")
	emit_signal("game_started", players, options)
	emit_signal("waiting_for", current_dealer, state)
	return 0


func deal_cards(name):
	last_touch = OS.get_ticks_msec()
	if state != STATE.DEAL:
		return ERRORS.NOT_READY_FOR_DEALING
	if name != current_dealer:
		return ERRORS.INCORRECT_PLAYER_DEAL
	var deck = _get_new_deck()
	if current_num_cards == hell_round:
		trump_card = JOKER
		deck.erase(JOKER)
	else:
		trump_card = deck.pop_front()
	for p in players:
		for i in range(current_num_cards):
			player_cards[p].append(deck.pop_front())
		player_cards[p].sort_custom(self, "sort_func_"+suit(trump_card))
	state = STATE.BID
	#emit_signal("changed")
	emit_signal("cards_dealt")
	emit_signal("waiting_for", current_player_turn, state)
	return 0
	

func place_bid(name, bid):
	last_touch = OS.get_ticks_msec()
	if state != STATE.BID:
		return ERRORS.NOT_BIDDING
	if name != current_player_turn:
		return ERRORS.INCORRECT_PLAYER_TURN
	if bid < 0 or bid > current_num_cards:
		return ERRORS.BID_OUT_OF_RANGE
	var total = 0
	var count = 0
	for b in player_bids.values():
		if b != null:
			count += 1
			total += b
	if count == num_players-1 and total+bid == current_num_cards:
		return ERRORS.BIDS_CANNOT_SUM_TO_CARDS
	player_bids[name] = bid
	current_player_turn = _next_player(current_player_turn)
	if count == num_players-1:
		state = STATE.PLAY
	#emit_signal("changed")
	emit_signal("bid_placed", name, bid)
	emit_signal("waiting_for", current_player_turn, state)
	return 0


func play_card(name, card):
	
	last_touch = OS.get_ticks_msec()
	
	# Checking.
	if state != STATE.PLAY:
		return ERRORS.NOT_PLAYING
	if name != current_player_turn: 
		return ERRORS.INCORRECT_PLAYER_TURN        
	if player_cards[name].find(card) == -1:
		return ERRORS.DOES_NOT_HAVE_CARD
	var num_trumps = 0
	var num_follow = 0
	var is_following = true if lead_card == null else (suit(card) == suit(lead_card) or (card == JOKER and suit(lead_card) == suit(trump_card)) or (lead_card == JOKER and suit(trump_card) == suit(card)))
	for c in player_cards[name]:
		if suit(c) == suit(trump_card) or c == JOKER:
			num_trumps += 1
		if lead_card != null and (suit(c) == suit(lead_card) or (c == JOKER and suit(lead_card) == suit(trump_card)) or (lead_card == JOKER and suit(c) == suit(trump_card))):
			num_follow += 1
	if not is_following and num_follow > 0:
		return ERRORS.NOT_FOLLOWING_SUIT
	if not trumps_broken and suit(card) in [suit(trump_card), suit(JOKER)] and num_trumps < player_cards[name].size() and current_hand.size() == 0:
		return ERRORS.TRUMPS_NOT_BROKEN
		
	# Playing.
	player_cards[name].erase(card)
	emit_signal("card_played", name, card, current_hand.size() == 0)
	if current_hand.size() == 0:
		lead_card = card
	current_hand.append([name, card])
	if suit(card) in [suit(trump_card), suit(JOKER)]:
		trumps_broken = true
	if current_hand.size() == num_players:
		var win_name = current_hand[0][0]  # GDScript limitation.
		var win_card = current_hand[0][1]  # GDScript limitation.
		for temp in current_hand.slice(1, num_players):  # GDScript limitation.
			var n = temp[0] ; var c = temp[1]  # GDScript limitation.
			if beats(c, win_card, lead_card, trump_card):
				win_name = n
				win_card = c
		player_tricks[win_name] += 1
		current_player_turn = win_name
		current_hand.clear()
		lead_card = null
		emit_signal("trick_completed", win_name)
	else:
		current_player_turn = _next_player(current_player_turn)
	if player_cards[current_player_turn].size() == 0:
		if remaining_rounds:
			var this_scores = _update_scores()
			current_num_cards = remaining_rounds.pop_front()
			player_bids = _reset_dict(null)
			player_tricks = _reset_dict(0)
			trump_card = ''
			lead_card = null
			trumps_broken = false
			current_dealer = _next_player(current_dealer)
			current_player_turn = _next_player(current_dealer)
			state = STATE.DEAL
			emit_signal("round_completed", this_scores, player_score, score_history)
		else:
			var this_scores = _update_scores()
			emit_signal("round_completed", this_scores, player_score, score_history)
			state = STATE.POST_GAME
			emit_signal("game_completed", score_history)
	
	#emit_signal("changed")
	if state != STATE.POST_GAME:
		emit_signal("waiting_for", current_dealer if state == STATE.DEAL else current_player_turn, state)
	return 0    


func _update_scores():
	var result = {}
	var row = [current_num_cards, {}]
	for p in players:
		var adj
		if player_tricks[p] == player_bids[p]:
			adj = player_bids[p] + 1
		else:
			adj = -abs(player_tricks[p] - player_bids[p])
		player_score[p] += adj
		result[p] = adj
		row[1][p] = [adj, player_score[p]]
	score_history.append(row)
	return result
