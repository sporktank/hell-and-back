extends Node


#https://gitlab.com/menip/godot-multiplayer-tutorials/-/blob/master/LobbyTutorial/Server/gamestate.gd
#https://cloud.google.com/free/docs/gcp-free-tier

#https://console.cloud.google.com/compute/instances?project=affable-envoy-275413&instancessize=50


const DEFAULT_PORT = 44444
const MAX_PLAYERS = 32


const REACTIONS = {
        -1: [
            "BULLSH*T", 
            "You've got to be kidding me.",
            "I suck at this game.",
            ":(",
            "#WDTS",
            "Have you played cards before?",
            "Oh, come on!",
        ],
        0: [
            "Pray to the gods!", 
            "Whose deal is it?",
            "Dumplings, anyone?",
            "#cardgods",
            "What're the scores?",
            "Get a life.",
            "Thanks for playing Hell & Back. :)",
        ],
        1: [
            "#differentials", 
            "Yeah, boi!",
            "BOOM!",
            "All about the differentials, baby.",
            "Smells like a winner..",
            "That's a winner if I've ever seen one.",
            "Bingo!",
        ]
    }


var players = {}

var server
func _ready():
    get_tree().connect("network_peer_connected", self, "_player_connected")
    get_tree().connect("network_peer_disconnected", self,"_player_disconnected")
    #create_server()
    #https://www.reddit.com/r/godot/comments/bux2hs/how_to_use_godots_high_level_multiplayer_api_with/
    server = WebSocketServer.new()
    server.listen(DEFAULT_PORT, PoolStringArray(), true)
    get_tree().set_network_peer(server)


func _process(delta):
    if Input.is_action_just_pressed("ui_cancel"): get_tree().quit()
    #if server.is_listening():
    #    server.poll()
    
    var now = OS.get_ticks_msec()
    var to_erase = []
    for game_num in games:
        var game = games[game_num]
        if (now - game.last_touch)/1000.0/60.0 > 30:  # Cancel games after 30 minutes of inactivity.
            for name in games_players[game_num]:
                var id = games_players[game_num][name]
                rpc_id(id, "game_cancelled", game_num)
            to_erase.append(game_num)
    if to_erase:
        for game_num in to_erase:
            dbg("Cancelling game " + str(game_num))
            games.erase(game_num)
        rpc("games_listed", make_games_list())


#func create_server():
#    var host = NetworkedMultiplayerENet.new()
#    var err = host.create_server(DEFAULT_PORT, MAX_PLAYERS)
#    if err == OK:
#        dbg("Successfully created server")
#        get_tree().set_network_peer(host)
#    else:
#        dbg("Could not create server, error " + str(err))


func dbg(text):
    var message = "[DEBUG] " + text
    print(message)
    $Debug.text += message + "\n"
    

func _player_connected(_id):
    dbg("Client " + str(_id) + " connected")
    rpc("games_listed", make_games_list())


func _player_disconnected(id):
    dbg("Client " + str(id) + " disconnected")
    for game_num in games:
        var game = games[game_num]
        for name in games_players[game_num]:
            if games_players[game_num][name] == id:
                if game.get_state_string() in ['pre-game', 'post-game']:
                    dbg("Game not started (or is finished) and player disconnected, removing " + name)
                    game.players.erase(name)
                else:
                    dbg("Game in progress, lost player " + name)
                    game.pause_game(name)
                    rpc("lost_player", game_num, name)
    rpc("games_listed", make_games_list())


remote func leave_game(game_num, name):
    var game = games[game_num]
    if game.get_state_string() in ['pre-game', 'post-game']:
        dbg("Game not started (or is finished) and player disconnected, removing " + name)
        game.players.erase(name)
    else:
        dbg("Game in progress, lost player " + name)
        game.pause_game(name)
        rpc("lost_player", game_num, name)
    rpc("games_listed", make_games_list())


var game_class = preload("res://Game.gd")
var games = {}
var games_players = {}  # Store the names and callee ids.


remote func create_game(options):
    var caller_id = get_tree().get_rpc_sender_id()
    var game_num = games.keys().max() + 1 if games.size() > 0 else 1  # TODO: Maybe start at higher numbers?
    var game = game_class.new(game_num, options)
    #game.connect("player_added",    self, "player_added",    [game_num])
    game.connect("game_started",    self, "game_started",    [game_num])
    game.connect("waiting_for",     self, "waiting_for",     [game_num])
    game.connect("cards_dealt",     self, "cards_dealt",     [game_num])
    game.connect("bid_placed",      self, "bid_placed",      [game_num])
    game.connect("card_played",     self, "card_played",     [game_num])
    game.connect("trick_completed", self, "trick_completed", [game_num])
    game.connect("round_completed", self, "round_completed", [game_num])
    game.connect("game_completed",  self, "game_completed",  [game_num])
    game.connect("resuming_game",   self, "resuming_game",   [game_num])
    games[game_num] = game
    games_players[game_num] = {}
    dbg("Created game num " + str(game_num))
    rpc_id(caller_id, "game_created", game_num)
    rpc("games_listed", make_games_list())
    
    
func make_games_list():
    var result = []
    for game_num in games.keys():
        var game = games[game_num]
        if game.is_joinable():
            result.append([game_num, game.players, game.lost_players])
    return result
    

remote func list_games():
    var caller_id = get_tree().get_rpc_sender_id()
    var result = make_games_list()
    dbg("Game list requested " + str(result))
    rpc_id(caller_id, "games_listed", result)


remote func join_game(game_num, name):
    var caller_id = get_tree().get_rpc_sender_id()
    var errno = games[game_num].add_player(name)
    if not errno:
        games_players[game_num][name] = caller_id
        dbg("Player " + str(name) + " joined game num " + str(game_num))
    rpc_id(caller_id, "game_joined", errno, game_num, name)
    rpc("games_listed", make_games_list())
    # Potentially resuming a game.
    if games[game_num].is_paused() and games[game_num].lost_players.size() == 0:
        for name in games_players[game_num]:
            var id = games_players[game_num][name]
            var game = games[game_num]
            var resume_data = {
                    "game_num": game_num,
                    "players": game.players,
                    "options": game.options,
                    "cards": game.player_cards[name],
                    "player_score": game.player_score,
                    "player_tricks": game.player_tricks,
                    "player_bids": game.player_bids,
                    "score_history": game.score_history,
                    "current_num_cards": game.current_num_cards,
                    "current_player_turn": game.current_player_turn,
                    "current_dealer": game.current_dealer,
                    "state": game.resume_state,
                    "current_hand": game.current_hand,
                    "trump_card": game.trump_card,
                }
            rpc_id(id, "resuming_game", resume_data)
        games[game_num].resume()


remote func start_game(game_num):
    var caller_id = get_tree().get_rpc_sender_id()
    var game = games[game_num]
    var errno = game.start_game()
    if errno:
        rpc_id(caller_id, "game_started", errno, game_num, null, null)
    else:
    #if not errno:
        dbg("Starting game num " + str(game_num))
        #for id in games_players[game_num].values():
            #rpc_id(id, "game_started", errno, game_num, games_players[game_num].keys())
            #rpc_id(id, "waiting_for", game.get_current_dealer(), game.get_state())
    dbg("Game num " + str(game_num) + " = " + str(game))
            

remote func deal_cards(game_num, name):
    dbg("Game " + str(game_num) + " being dealt by " + name)
    var caller_id = get_tree().get_rpc_sender_id()
    var game = games[game_num]
    var errno = game.deal_cards(name)
    if errno:
        rpc_id(caller_id, "cards_dealt", errno, null, null, null)
    dbg("Game num " + str(game_num) + " = " + str(game))


remote func place_bid(game_num, name, amount):
    var caller_id = get_tree().get_rpc_sender_id()
    var game = games[game_num]
    var errno = game.place_bid(name, amount)
    if errno:
        rpc_id(caller_id, "bid_placed", errno, null, null)
    dbg("Game num " + str(game_num) + " = " + str(game))


remote func play_card(game_num, name, card):
    var caller_id = get_tree().get_rpc_sender_id()
    var game = games[game_num]
    var errno = game.play_card(name, card)
    if errno:
        rpc_id(caller_id, "card_played", errno, null, null, null)
    dbg("Game num " + str(game_num) + " = " + str(game))


remote func send_reaction(game_num, player_name, reaction):
    var list = REACTIONS[reaction]
    var text = list[randi() % list.size()]
    for name in games_players[game_num]:
        var id = games_players[game_num][name]
        rpc_id(id, "receive_reaction", player_name, text)


# ------------------------------------


#func player_added(player_name, game_num):
#    dbg("Callback player_added(%s, %s)" % [game_num, player_name])
#    if games[game_num].is_paused() and games[game_num].lost_players.size() == 0:
#        for name in games_players[game_num]:
#            var id = games_players[game_num][name]
#            rpc_id(id, "resuming_game")  # TODO
#        games[game_num].resume()


func game_started(players, options, game_num):
    dbg("Callback game_started(%s, %s)" % [game_num, players])
    for name in games_players[game_num]:
        var id = games_players[game_num][name]
        rpc_id(id, "game_started", 0, game_num, players, options)


func waiting_for(player_name, state, game_num):
    dbg("Callback waiting_for(%s, %s, %s)" % [game_num, player_name, state])
    for name in games_players[game_num]:
        var id = games_players[game_num][name]
        rpc_id(id, "waiting_for", player_name, state)


func cards_dealt(game_num):
    dbg("Callback cards_dealt(%s)" % [game_num])
    for name in games_players[game_num]:
        var id = games_players[game_num][name]
        var game = games[game_num]
        rpc_id(id, "cards_dealt", 0, game.get_cards(name), game.get_trump_card(), game.get_current_dealer())
        
      
func bid_placed(player_name, amount, game_num):
    dbg("Callback bid_placed(%s, %s, %s)" % [game_num, player_name, amount])
    for to_name in games_players[game_num]:
        var id = games_players[game_num][to_name]
        rpc_id(id, "bid_placed", 0, player_name, amount)


func card_played(player_name, card, first_card, game_num):
    dbg("Callback card_played(%s, %s, %s)" % [game_num, player_name, card])
    for to_name in games_players[game_num]:
        var id = games_players[game_num][to_name]
        rpc_id(id, "card_played", 0, player_name, card, first_card)


func trick_completed(winner, game_num):
    dbg("Callback trick_completed(%s, %s)" % [game_num, winner])
    for name in games_players[game_num]:
        var id = games_players[game_num][name]
        rpc_id(id, "trick_completed", winner)


func round_completed(this_scores, scores, score_history, game_num):
    dbg("Callback round_completed(%s)" % [game_num])
    for name in games_players[game_num]:
        var id = games_players[game_num][name]
        rpc_id(id, "round_completed", this_scores, scores, score_history)


func game_completed(score_history, game_num):
    dbg("Callback game_completed(%s)" % [game_num])
    for name in games_players[game_num]:
        var id = games_players[game_num][name]
        rpc_id(id, "game_completed", score_history)
