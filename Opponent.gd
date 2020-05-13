extends Node2D

# TODO: A lot of this is duplicated in Player.


var player_name
var num_cards = 0
var bid = null
var tricks = 0
var score = 0
var is_dealer = false
var trump_card = null
var first_lead = false


func _ready():
    $DeckBG.set_card(Global.JOKER, false)
    $DeckBG/AnimatedSprite.modulate = Color(0.0, 0.0, 0.0, 1.0)


func setup(player_name):
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
    

func round_reset():
    num_cards = 0
    bid = null
    tricks = 0
    update()
    

func set_bid(amount):
    bid = amount
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


func set_num_cards(num_cards):
    self.num_cards = num_cards
    update()


func set_cards(cards):
    set_num_cards(cards.size())


func get_card(card_num):
    return get_node("Card"+str(3 if card_num > 3 else card_num))


func card_played(card):
    num_cards -= 1
    update()
    
    
func update():
    
    # Deck.
    if is_dealer:
        $Deck.visible = true
        if trump_card == null:
            $Deck.set_card(Global.JOKER, false)  # Dummy card, face down anyway.
        else:
            $Deck.set_card(trump_card, true, false)  # TODO: Maybe don't highlight the turned up card?
    else:
        $Deck.visible = false
        
    # Cards.
    $Card1.set_card(Global.JOKER if num_cards >= 1 else null, false)
    $Card2.set_card(Global.JOKER if num_cards >= 2 else null, false)
    $Card3.set_card(Global.JOKER if num_cards >= 3 else null, false)
    
    # Bids.
    $Bid.set_value(bid)
        
    # Info.
    $InfoPivot/Info.text = "%s\n%s/%s\n%s" % [
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
    
    # Rotations.
    $InfoPivot.rotation = -rotation
    $Bid.rotation = -rotation
    #$Deck.rotation = -rotation
    #$DeckBG.rotation = -rotation
#    $Speech.rotation = -rotation
#    match (int(rotation_degrees) * 100*360) % 360:
#        90:
#            $Speech.position.y = $OffScreen.position.y - 200
#        180: 
#            $Speech/Sprite.rotation_degrees = 180
#        270:
#            $Speech.position.y = $OffScreen.position.y - 200
#            $Speech/Sprite.scale = Vector2(-1,1)

