import naylib, math, random
import ../utils, ../player, ../ui

type
  Card = object
    value: int
    suit: string
  
  BlackjackState = enum
    Betting, PlayerTurn, DealerTurn, Result
  
  Blackjack* = ref object
    position*: Vector3
    playerHand*: seq[Card]
    dealerHand*: seq[Card]
    deck*: seq[Card]
    state*: BlackjackState
    bet*: int
    dealerRevealed*: bool

const 
  SUITS = ["♥", "♦", "♣", "♠"]
  CARD_VALUES = [2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10, 11]  # J, Q, K = 10, A = 11

proc newCard(): Card =
  result.value = CARD_VALUES[rand(CARD_VALUES.len - 1)]
  result.suit = SUITS[rand(SUITS.len - 1)]

proc createDeck(): seq[Card] =
  result = @[]
  for _ in 0..51:  # 52 card deck
    result.add(newCard())

proc calculateHandValue(hand: seq[Card]): int =
  result = 0
  var aces = 0
  
  for card in hand:
    result += card.value
    if card.value == 11:
      aces += 1
  
  # Adjust for aces
  while result > 21 and aces > 0:
    result -= 10
    aces -= 1

proc cardToString(card: Card): string =
  if card.value == 11:
    return "A" & card.suit
  elif card.value == 10:
    return "T" & card.suit
  else:
    return $card.value & card.suit

proc newBlackjack*(pos: Vector3): Blackjack =
  result = Blackjack()
  result.position = pos
  result.playerHand = @[]
  result.dealerHand = @[]
  result.deck = @[]
  result.state = Betting
  result.bet = 0
  result.dealerRevealed = false

proc draw3D*(blackjack: Blackjack) =
  # Table
  let tablePos = Vector3(
    x: blackjack.position.x,
    y: blackjack.position.y + 0.5,
    z: blackjack.position.z
  )
  drawCube(tablePos, 3.0, 0.2, 2.0, DarkGreen)
  drawCubeWires(tablePos, 3.0, 0.2, 2.0, Gold)
  
  # Table legs
  for ix in [-1, 1]:
    for iz in [-1, 1]:
      let legPos = Vector3(
        x: tablePos.x + ix.float * 1.3,
        y: blackjack.position.y - 0.25,
        z: tablePos.z + iz.float * 0.8
      )
      drawCube(legPos, 0.15, 1.0, 0.15, DarkBrown)
  
  # Card placeholder spots
  let cardPos1 = Vector3(
    x: tablePos.x - 0.5,
    y: tablePos.y + 0.11,
    z: tablePos.z
  )
  drawCube(cardPos1, 0.4, 0.01, 0.6, White)
  
  let cardPos2 = Vector3(
    x: tablePos.x + 0.5,
    y: tablePos.y + 0.11,
    z: tablePos.z
  )
  drawCube(cardPos2, 0.4, 0.01, 0.6, White)

proc dealInitialCards(blackjack: Blackjack) =
  blackjack.deck = createDeck()
  blackjack.playerHand = @[]
  blackjack.dealerHand = @[]
  blackjack.dealerRevealed = false
  
  # Deal 2 cards each
  for _ in 0..1:
    blackjack.playerHand.add(newCard())
    blackjack.dealerHand.add(newCard())

proc hit(blackjack: Blackjack) =
  blackjack.playerHand.add(newCard())

proc play*(blackjack: Blackjack, player: Player): bool =
  case blackjack.state:
  of Betting:
    var messages: seq[string] = @[]
    messages.add("=== BLACKJACK ===")
    messages.add("")
    messages.add("Get as close to 21 as possible")
    messages.add("without going over!")
    messages.add("")
    messages.add("Choose your bet:")
    messages.add("")
    messages.add("[1] $10   [2] $50   [3] $100")
    messages.add("[ESC] Back")
    
    if isKeyPressed(One):
      if player.removeMoney(10):
        blackjack.bet = 10
        dealInitialCards(blackjack)
        blackjack.state = PlayerTurn
      else:
        messages.add("")
        messages.add("Not enough money!")
    elif isKeyPressed(Two):
      if player.removeMoney(50):
        blackjack.bet = 50
        dealInitialCards(blackjack)
        blackjack.state = PlayerTurn
      else:
        messages.add("")
        messages.add("Not enough money!")
    elif isKeyPressed(Three):
      if player.removeMoney(100):
        blackjack.bet = 100
        dealInitialCards(blackjack)
        blackjack.state = PlayerTurn
      else:
        messages.add("")
        messages.add("Not enough money!")
    
    drawMinigameUI("BLACKJACK", player, messages)
    
    if isKeyPressed(Escape):
      return true
  
  of PlayerTurn:
    var messages: seq[string] = @[]
    messages.add("=== YOUR TURN ===")
    messages.add("")
    messages.add("Dealer shows: " & cardToString(blackjack.dealerHand[0]) & " [?]")
    messages.add("")
    
    var playerCards = "Your hand: "
    for i, card in blackjack.playerHand:
      playerCards &= cardToString(card)
      if i < blackjack.playerHand.len - 1:
        playerCards &= ", "
    messages.add(playerCards)
    
    let playerValue = calculateHandValue(blackjack.playerHand)
    messages.add("Total: " & $playerValue)
    messages.add("")
    
    if playerValue > 21:
      blackjack.state = Result
    else:
      messages.add("[H] Hit (take another card)")
      messages.add("[S] Stand (end turn)")
    
    if isKeyPressed(H) and playerValue <= 21:
      hit(blackjack)
    elif isKeyPressed(S) and playerValue <= 21:
      blackjack.state = DealerTurn
      blackjack.dealerRevealed = true
    
    drawMinigameUI("BLACKJACK", player, messages)
  
  of DealerTurn:
    var messages: seq[string] = @[]
    messages.add("=== DEALER'S TURN ===")
    messages.add("")
    
    var dealerCards = "Dealer: "
    for i, card in blackjack.dealerHand:
      dealerCards &= cardToString(card)
      if i < blackjack.dealerHand.len - 1:
        dealerCards &= ", "
    messages.add(dealerCards)
    
    let dealerValue = calculateHandValue(blackjack.dealerHand)
    messages.add("Total: " & $dealerValue)
    messages.add("")
    
    # Dealer hits on 16 or less
    if dealerValue < 17:
      messages.add("Dealer hits...")
      blackjack.dealerHand.add(newCard())
    else:
      messages.add("Dealer stands")
      blackjack.state = Result
    
    messages.add("")
    messages.add("Press any key to continue...")
    
    drawMinigameUI("BLACKJACK", player, messages)
    
    if isKeyPressed(Space) or isKeyPressed(Enter):
      if dealerValue >= 17 or dealerValue > 21:
        blackjack.state = Result
  
  of Result:
    var messages: seq[string] = @[]
    messages.add("=== RESULT ===")
    messages.add("")
    
    let playerValue = calculateHandValue(blackjack.playerHand)
    let dealerValue = calculateHandValue(blackjack.dealerHand)
    
    var playerCards = "You: "
    for i, card in blackjack.playerHand:
      playerCards &= cardToString(card)
      if i < blackjack.playerHand.len - 1:
        playerCards &= ", "
    messages.add(playerCards)
    messages.add("Total: " & $playerValue)
    messages.add("")
    
    var dealerCards = "Dealer: "
    for i, card in blackjack.dealerHand:
      dealerCards &= cardToString(card)
      if i < blackjack.dealerHand.len - 1:
        dealerCards &= ", "
    messages.add(dealerCards)
    messages.add("Total: " & $dealerValue)
    messages.add("")
    
    # Determine winner
    if playerValue > 21:
      messages.add("BUST! You lose")
      messages.add("Lost: " & formatMoney(blackjack.bet))
    elif dealerValue > 21:
      let winnings = blackjack.bet * 2
      player.addMoney(winnings)
      messages.add("Dealer busts! YOU WIN!")
      messages.add("Won: " & formatMoney(winnings))
    elif playerValue > dealerValue:
      let winnings = blackjack.bet * 2
      player.addMoney(winnings)
      messages.add("YOU WIN!")
      messages.add("Won: " & formatMoney(winnings))
    elif playerValue == dealerValue:
      player.addMoney(blackjack.bet)
      messages.add("PUSH - It's a tie")
      messages.add("Bet returned")
    else:
      messages.add("Dealer wins")
      messages.add("Lost: " & formatMoney(blackjack.bet))
    
    messages.add("")
    messages.add("Press any key to continue...")
    
    drawMinigameUI("BLACKJACK", player, messages)
    
    if isKeyPressed(Space) or isKeyPressed(Enter) or isKeyPressed(Escape):
      blackjack.state = Betting
      blackjack.bet = 0
      return true
  
  return false