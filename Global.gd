extends Node


const MAX_BID = 13

const SUITS = ['s','c','d','h']
const FACES = ['2','3','4','5','6','7','8','9','t','j','q','k','a']
const JOKER = 'xx'


func suit(card): return card.right(1)
func face(card): return card.left(1)
func fval(card): return FACES.find(card.left(1))   

