extends Node2D


enum LOBBY_STATE {
		NOT_CONNECTED,
		NOT_IN_GAME,
		JOINED_GAME,
		PLAYING_GAME
	}
var lobby_state = LOBBY_STATE.NOT_CONNECTED


var main


func _ready():
	main = get_parent()
	#$Group/ScorePad.text = "  -------\n  " + format_score(2) + " " + format_score(-10)
	#$Group/GamesList.max_text_lines = 2
	#$Group/GamesList.fixed_column_width = 200
	#$Group/GamesList.add_item("#1 [p0001? p0001? p0001? p0001? p0001? p0001? p0001? p0001?]")
	# Can't figure out how to get text to wrap around.


func _process(delta):
	match lobby_state:
		LOBBY_STATE.NOT_CONNECTED:
			$Group/Create.disabled = true
			$Group/Join.disabled = true
			$Group/Leave.disabled = true
			$Group/Start.disabled = true
			$Group/NameText.editable = false
			#$Group/NameText.text = ""
			$Group/PlayingFor.editable = false
			#$Group/PlayingFor.text = ""
			$Group/HellRound.editable = false
			$Group/Bowers.disabled = true
			$Group/FairCards.disabled = true
			$Group/BlindScoring.disabled = true
			$Group/FutureOption.disabled = true
			
		LOBBY_STATE.NOT_IN_GAME:
			$Group/Create.disabled = false
			$Group/Join.disabled = false
			$Group/Leave.disabled = true
			$Group/Start.disabled = true
			$Group/NameText.editable = true
			$Group/PlayingFor.editable = true
			$Group/HellRound.editable = true
			$Group/Bowers.disabled = true # TODO
			$Group/FairCards.disabled = true # TODO
			$Group/BlindScoring.disabled = true # TODO
			$Group/FutureOption.disabled = true # TODO
			
		LOBBY_STATE.JOINED_GAME:
			$Group/Create.disabled = true
			$Group/Join.disabled = true
			$Group/Leave.disabled = false
			$Group/Start.disabled = false
			$Group/NameText.editable = false
			$Group/PlayingFor.editable = false
			$Group/HellRound.editable = false
			$Group/Bowers.disabled = true # TODO
			$Group/FairCards.disabled = true # TODO
			$Group/BlindScoring.disabled = true # TODO
			$Group/FutureOption.disabled = true # TODO
			# TODO: Currently options are not sent until game starts..
			#$Group/PlayingFor.text = main.game_options["playing_for"]
			#$Group/HellRound.value = main.game_options["hell_round"]
			
		LOBBY_STATE.PLAYING_GAME:
			$Group/Create.disabled = true
			$Group/Join.disabled = true
			$Group/Leave.disabled = false
			$Group/Start.disabled = true
			$Group/NameText.editable = false
			$Group/PlayingFor.editable = false
			$Group/HellRound.editable = false
			$Group/Bowers.disabled = true # TODO
			$Group/FairCards.disabled = true # TODO
			$Group/BlindScoring.disabled = true # TODO
			$Group/FutureOption.disabled = true # TODO


func _on_Connect_pressed():
	main.connect_to_server($Group/IPText.text)


func _on_Update_pressed():
	main.list_games()


func _on_Create_pressed():
	main.create_game($Group/PlayingFor.text, int($Group/HellRound.value))


func set_server_status(status):
	$Group/ServerStatus.text = "SERVER STATUS: %s" % [status]
	lobby_state = LOBBY_STATE.NOT_IN_GAME if status == "CONNECTED" else LOBBY_STATE.NOT_CONNECTED


func set_joined_game():
	lobby_state = LOBBY_STATE.JOINED_GAME
	

func set_playing_game():
	lobby_state = LOBBY_STATE.PLAYING_GAME
	

func set_left_game():
	lobby_state = LOBBY_STATE.NOT_IN_GAME


func get_game_num_from_list():
	if not $Group/GamesList.is_anything_selected():
		return null
	var text = $Group/GamesList.get_item_text($Group/GamesList.get_selected_items()[0])
	return int(text.lstrip("#").split(" ")[0])


func _on_Join_pressed():
	var game_num = get_game_num_from_list()
	var player_name = $Group/NameText.text.strip_edges().to_upper()
	if game_num and player_name:
		main.join_game(game_num, player_name)
		main.set_lobby_status("Joining game..")
	else:
		main.dbg("Cannot join game num " + str(game_num) + " as " + str(player_name))
		if game_num == null:
			main.set_lobby_status("No game selected.")
		else:
			main.set_lobby_status("No name entered.")


func _on_Menu_pressed():
	#main.get_node("MenuSound").play()
	$Group.visible = not $Group.visible
	$Group/Credits.visible = false


func _on_Quit_pressed():
	get_tree().quit()


func _on_Start_pressed():
	main.start_game()


func _on_Debug_pressed():
	main.get_node("Debug").visible = not main.get_node("Debug").visible


func format_score(x):
	var res = str(abs(x))
	if x < 0: res = "-" + res
	if x > 0: res = "+" + res
	res = "   " + res
	return res.right(res.length() - 3)


class ScoreSorter:
	static func sort_scores(a, b):
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])
		

func update_scorepad():
	
	var header = " #"
	var sep = "--"
	var rounds = []
	var result = "  "
	var hell = main.game_options["hell_round"]
	var num_rounds = 2*hell - 1
	
	var rank = {}
	var temp = []
	for p in main.all_players:
		temp.append([-main.current_scores[p], p])
	temp.sort_custom(ScoreSorter, "sort_scores") 
	main.dbg(str(temp))
	var prev_val = null
	var prev_rank = null
	for row in temp:
		rank[row[1]] = rank.size()+1 if prev_val == null or row[0] != prev_val else prev_rank
		prev_val = row[0]
		prev_rank = rank[row[1]]
	main.dbg(str(rank))
	
	for p in main.all_players:
		header += "   %-5s " % [p]
		sep += "  -------"
		result += "  " + format_score(main.current_scores[p]) + " (%d)" % [rank[p]]
	
	var count = 0
	for row in main.current_score_history:
		var num = row[0]
		var scores = row[1]
		rounds.append("%2d" % [num] if num < hell else " H")
		for p in main.all_players:
			main.dbg("num = " + str(num) + " p = " + str(p) + " scores[p] = " + str(scores[p]))
			rounds[-1] += "  " + format_score(scores[p][0]) + " " + format_score(scores[p][1])
		count += 1
	
	for num in range(count+1, num_rounds+1):
		rounds.append(" H" if num == hell else "%2d" % [num if num < hell else 2*hell-num])
	
	var text = ""
	text += header + "\n"
	text += sep + "\n"
	for r in rounds: text += r + "\n"
	text += sep + "\n"
	text += result
	$Group/ScorePad.text = text
	
	var scale
	match main.all_players.size():
		1, 2, 3, 4: scale = 1
		5:          scale = 0.83*0.95  # Doesn't quite work correctly on HTML5..
		6:          scale = 0.7*0.95
		7:          scale = 0.6*0.95
		8:          scale = 0.53*0.95
	$Group/ScorePad.rect_scale = Vector2(scale, 1)
	$Group/ScorePad.rect_size = Vector2(400/scale, 560)


func _on_CreditsButton_pressed():
	$Group/Credits.visible = not $Group/Credits.visible
	

func _on_CreditsClose_pressed():
	$Group/Credits.visible = false


func _on_Leave_pressed():
	main.leave_game()
