import raylib, rlgl, math, random
import ../utils, ../player, ../ui

type
  Card = object
    value: int
    suit: string
    slideOffset: float  # Animation offset
    flipProgress: float  # For flip animation
  
  BlackjackState = enum
    Betting, Dealing, PlayerTurn, DealerTurn, Result
  
  Blackjack* = ref object
    position*: Vector3
    playerHand*: seq[Card]
    dealerHand*: seq[Card]
    deck*: seq[Card]
    state*: BlackjackState
    bet*: int
    dealerRevealed*: bool
    moneyAwarded*: bool
    moneyToAward*: int
    moneyAwardedSoFar*: int
    moneyTimer*: float
    dealTimer*: float  # For dealing animation
    cardsToDeal*: int  # Track dealing progress
    pulseTimer*: float  # For winning card pulse
    chipStackHeight*: float  # Animated chip stack
    dealerThinkTimer*: float  # Pause before dealer acts
    transitionTimer*: float  # Smooth state transitions

const 
  SUITS = ["♥", "♦", "♣", "♠"]
  CARD_VALUES = [2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10, 11]

proc newCard(): Card =
  result.value = CARD_VALUES[rand(CARD_VALUES.len - 1)]
  result.suit = SUITS[rand(SUITS.len - 1)]
  result.slideOffset = 1.0  # Start off screen
  result.flipProgress = 0.0

proc createDeck(): seq[Card] =
  result = @[]
  for _ in 0..51:
    result.add(newCard())

proc calculateHandValue(hand: seq[Card]): int =
  result = 0
  var aces = 0
  
  for card in hand:
    result += card.value
    if card.value == 11:
      aces += 1
  
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
  result.moneyAwarded = false
  result.moneyToAward = 0
  result.moneyAwardedSoFar = 0
  result.moneyTimer = 0.0
  result.dealTimer = 0.0
  result.cardsToDeal = 0
  result.pulseTimer = 0.0
  result.chipStackHeight = 0.0
  result.dealerThinkTimer = 0.0
  result.transitionTimer = 0.0

proc draw3D*(blackjack: Blackjack) =
  # --- Rotar 180° en Y para que mire hacia el jugador ---
  pushMatrix()
  translatef(blackjack.position.x, blackjack.position.y, blackjack.position.z)
  rotatef(180, 0, 1, 0)
  translatef(-blackjack.position.x, -blackjack.position.y, -blackjack.position.z)
  
  # Table with subtle animations
  let tableBob = sin(getTime() * 0.5) * 0.01
  let tablePos = Vector3(
    x: blackjack.position.x,
    y: blackjack.position.y + 0.5 + tableBob,
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
  
  # Animated chip stack based on bet
  if blackjack.chipStackHeight > 0.0:
    let chipPos = Vector3(
      x: tablePos.x,
      y: tablePos.y + 0.15 + blackjack.chipStackHeight * 0.05,
      z: tablePos.z + 0.5
    )
    let chips = int(blackjack.chipStackHeight)
    for i in 0..<chips:
      let stackPos = Vector3(
        x: chipPos.x,
        y: chipPos.y + i.float * 0.05,
        z: chipPos.z
      )
      drawCylinder(stackPos, 0.15, 0.15, 0.04, 8, Gold)
      drawCylinderWires(stackPos, 0.15, 0.15, 0.04, 8, DarkGray)
  
  # Card placeholder spots with animated positions
  let pulse = if blackjack.pulseTimer > 0.0: 
                sin(blackjack.pulseTimer * 10.0) * 0.05 + 1.0
              else: 1.0
  
  # Player cards area
  let cardPos1 = Vector3(
    x: tablePos.x - 0.5,
    y: tablePos.y + 0.11,
    z: tablePos.z
  )
  drawCube(cardPos1, 0.4 * pulse, 0.01, 0.6 * pulse, White)
  
  # Dealer cards area
  let cardPos2 = Vector3(
    x: tablePos.x + 0.5,
    y: tablePos.y + 0.11,
    z: tablePos.z
  )
  drawCube(cardPos2, 0.4, 0.01, 0.6, White)
  
  # Draw card representations as small cubes with slide animation
  for i, card in blackjack.playerHand:
    let slideIn = 1.0 - card.slideOffset
    let cardVisPos = Vector3(
      x: tablePos.x - 0.8 + i.float * 0.15 + card.slideOffset * -2.0,
      y: tablePos.y + 0.15 + (1.0 - slideIn) * 0.5,
      z: tablePos.z - 0.3
    )
    drawCube(cardVisPos, 0.12, 0.01, 0.18, White)
    if blackjack.pulseTimer > 0.0:
      drawCubeWires(cardVisPos, 0.13, 0.02, 0.19, Gold)
  
  for i, card in blackjack.dealerHand:
    let slideIn = 1.0 - card.slideOffset
    let isHidden = i == 1 and not blackjack.dealerRevealed
    let flipScale = if isHidden: abs(cos(card.flipProgress * PI)) else: 1.0
    
    let cardVisPos = Vector3(
      x: tablePos.x + 0.8 - i.float * 0.15 + card.slideOffset * 2.0,
      y: tablePos.y + 0.15 + (1.0 - slideIn) * 0.5,
      z: tablePos.z + 0.3
    )
    
    let cardColor = if isHidden: Red else: White
    drawCube(cardVisPos, 0.12 * flipScale, 0.01, 0.18, cardColor)
  
  # --- Restaurar matriz ---
  popMatrix()

proc update*(blackjack: Blackjack, deltaTime: float) =
  # Update card slide animations
  for card in blackjack.playerHand.mitems:
    if card.slideOffset > 0.0:
      card.slideOffset -= deltaTime * 3.0
      if card.slideOffset < 0.0:
        card.slideOffset = 0.0
  
  for card in blackjack.dealerHand.mitems:
    if card.slideOffset > 0.0:
      card.slideOffset -= deltaTime * 3.0
      if card.slideOffset < 0.0:
        card.slideOffset = 0.0
    
    # Update flip animation for dealer's hidden card
    if not blackjack.dealerRevealed and card.flipProgress < 1.0:
      card.flipProgress += deltaTime * 2.0
      if card.flipProgress > 1.0:
        card.flipProgress = 1.0
  
  # Update chip stack animation
  let targetHeight = if blackjack.bet > 0: 
                       float(blackjack.bet div 10) 
                     else: 0.0
  
  if blackjack.chipStackHeight < targetHeight:
    blackjack.chipStackHeight += deltaTime * 10.0
    if blackjack.chipStackHeight > targetHeight:
      blackjack.chipStackHeight = targetHeight
  elif blackjack.chipStackHeight > targetHeight:
    blackjack.chipStackHeight -= deltaTime * 10.0
    if blackjack.chipStackHeight < targetHeight:
      blackjack.chipStackHeight = targetHeight
  
  # Update pulse timer
  if blackjack.pulseTimer > 0.0:
    blackjack.pulseTimer -= deltaTime
    if blackjack.pulseTimer < 0.0:
      blackjack.pulseTimer = 0.0
  
  # Update dealer think timer
  if blackjack.dealerThinkTimer > 0.0:
    blackjack.dealerThinkTimer -= deltaTime
  
  # Update transition timer
  if blackjack.transitionTimer > 0.0:
    blackjack.transitionTimer -= deltaTime

proc dealInitialCards(blackjack: Blackjack) =
  blackjack.deck = createDeck()
  blackjack.playerHand = @[]
  blackjack.dealerHand = @[]
  blackjack.dealerRevealed = false
  blackjack.state = Dealing
  blackjack.cardsToDeal = 4
  blackjack.dealTimer = 0.0

proc dealNextCard(blackjack: Blackjack) =
  # Deal cards one at a time with timing
  if blackjack.cardsToDeal > 0:
    var card = newCard()
    card.slideOffset = 1.0
    
    if blackjack.cardsToDeal == 4 or blackjack.cardsToDeal == 2:
      blackjack.playerHand.add(card)
    else:
      blackjack.dealerHand.add(card)
    
    blackjack.cardsToDeal -= 1

proc hit(blackjack: Blackjack) =
  var card = newCard()
  card.slideOffset = 1.0
  blackjack.playerHand.add(card)

proc play*(blackjack: Blackjack, player: Player): bool =
  blackjack.update(getFrameTime())
  
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
      else:
        messages.add("")
        messages.add("Not enough money!")
    elif isKeyPressed(Two):
      if player.removeMoney(50):
        blackjack.bet = 50
        dealInitialCards(blackjack)
      else:
        messages.add("")
        messages.add("Not enough money!")
    elif isKeyPressed(Three):
      if player.removeMoney(100):
        blackjack.bet = 100
        dealInitialCards(blackjack)
      else:
        messages.add("")
        messages.add("Not enough money!")
    
    drawMinigameUI("BLACKJACK", player, messages)
    
    if isKeyPressed(Escape):
      return true
  
  of Dealing:
    blackjack.dealTimer += getFrameTime()
    
    if blackjack.dealTimer >= 0.4 and blackjack.cardsToDeal > 0:
      dealNextCard(blackjack)
      blackjack.dealTimer = 0.0
    
    if blackjack.cardsToDeal == 0:
      blackjack.state = PlayerTurn
      blackjack.transitionTimer = 0.5
    
    var messages: seq[string] = @[]
    messages.add("=== DEALING ===")
    drawMinigameUI("BLACKJACK", player, messages)
  
  of PlayerTurn:
    if blackjack.transitionTimer > 0.0:
      var messages: seq[string] = @[]
      messages.add("=== YOUR TURN ===")
      drawMinigameUI("BLACKJACK", player, messages)
      return false
    
    var messages: seq[string] = @[]
    messages.add("=== YOUR TURN ===")
    messages.add("")
    
    let playerValue = calculateHandValue(blackjack.playerHand)
    messages.add("You: " & $playerValue)
    messages.add("Dealer: " & $blackjack.dealerHand[0].value & " + ?")
    messages.add("")
    
    if playerValue > 21:
      blackjack.state = Result
      blackjack.moneyAwarded = false
      blackjack.moneyToAward = 0
      blackjack.moneyAwardedSoFar = 0
      blackjack.moneyTimer = 0.0
      blackjack.transitionTimer = 0.8
    else:
      messages.add("[H] Hit   [S] Stand")
    
    if isKeyPressed(H) and playerValue <= 21:
      hit(blackjack)
    elif isKeyPressed(S) and playerValue <= 21:
      blackjack.state = DealerTurn
      blackjack.dealerRevealed = true
      blackjack.dealerThinkTimer = 1.0
      blackjack.moneyAwarded = false
      blackjack.moneyToAward = 0
      blackjack.moneyAwardedSoFar = 0
      blackjack.moneyTimer = 0.0
      if blackjack.dealerHand.len > 1:
        blackjack.dealerHand[1].flipProgress = 0.0
    
    drawMinigameUI("BLACKJACK", player, messages)
  
  of DealerTurn:
    var messages: seq[string] = @[]
    messages.add("=== DEALER'S TURN ===")
    messages.add("")
    
    let dealerValue = calculateHandValue(blackjack.dealerHand)
    messages.add("Dealer: " & $dealerValue)
    
    if blackjack.dealerThinkTimer > 0.0:
      messages.add("")
      messages.add("Thinking...")
    else:
      if dealerValue < 17:
        messages.add("Dealer hits")
        var card = newCard()
        card.slideOffset = 1.0
        blackjack.dealerHand.add(card)
        blackjack.dealerThinkTimer = 1.0
      else:
        messages.add("Dealer stands")
        blackjack.state = Result
        blackjack.transitionTimer = 0.8
    
    drawMinigameUI("BLACKJACK", player, messages)
    
    if isKeyPressed(Space) or isKeyPressed(Enter):
      if dealerValue >= 17 or dealerValue > 21:
        blackjack.state = Result
        blackjack.transitionTimer = 0.8
  
  of Result:
    if blackjack.transitionTimer > 0.0:
      var messages: seq[string] = @[]
      messages.add("=== RESULT ===")
      drawMinigameUI("BLACKJACK", player, messages)
      return false
    
    var messages: seq[string] = @[]
    messages.add("=== RESULT ===")
    messages.add("")
    
    let playerValue = calculateHandValue(blackjack.playerHand)
    let dealerValue = calculateHandValue(blackjack.dealerHand)
    
    messages.add("You: " & $playerValue)
    messages.add("Dealer: " & $dealerValue)
    messages.add("")
    
    if not blackjack.moneyAwarded:
      if playerValue > 21:
        blackjack.moneyToAward = 0
        messages.add("💥 BUST! You lose")
        messages.add("Lost: " & formatMoney(blackjack.bet))
      elif dealerValue > 21:
        blackjack.moneyToAward = blackjack.bet * 2
        blackjack.pulseTimer = 2.0
        messages.add("🎉 Dealer busts! YOU WIN!")
        messages.add("Won: " & formatMoney(blackjack.moneyToAward))
      elif playerValue > dealerValue:
        blackjack.moneyToAward = blackjack.bet * 2
        blackjack.pulseTimer = 2.0
        messages.add("🎉 YOU WIN!")
        messages.add("Won: " & formatMoney(blackjack.moneyToAward))
      elif playerValue == dealerValue:
        blackjack.moneyToAward = blackjack.bet
        messages.add("🤝 PUSH - It's a tie")
        messages.add("Bet returned")
      else:
        blackjack.moneyToAward = 0
        messages.add("😞 Dealer wins")
        messages.add("Lost: " & formatMoney(blackjack.bet))
      blackjack.moneyAwarded = true
    else:
      blackjack.moneyTimer += getFrameTime()
      
      if blackjack.moneyTimer >= 0.08 and blackjack.moneyAwardedSoFar < blackjack.moneyToAward:
        blackjack.moneyTimer = 0.0
        
        var increment: int
        if blackjack.moneyToAward < 100:
          increment = 5
        elif blackjack.moneyToAward < 500:
          increment = 10
        elif blackjack.moneyToAward < 1000:
          increment = 25
        else:
          increment = 50
        
        increment = min(increment, blackjack.moneyToAward - blackjack.moneyAwardedSoFar)
        player.addMoney(increment)
        blackjack.moneyAwardedSoFar += increment
      
      if playerValue > 21:
        messages.add("💥 BUST! You lose")
        messages.add("Lost: " & formatMoney(blackjack.bet))
      elif dealerValue > 21:
        messages.add("🎉 Dealer busts! YOU WIN!")
        messages.add("Won: " & formatMoney(blackjack.moneyToAward))
      elif playerValue > dealerValue:
        messages.add("🎉 YOU WIN!")
        messages.add("Won: " & formatMoney(blackjack.moneyToAward))
      elif playerValue == dealerValue:
        messages.add("🤝 PUSH - It's a tie")
        messages.add("Bet returned")
      else:
        messages.add("😞 Dealer wins")
        messages.add("Lost: " & formatMoney(blackjack.bet))
    
    messages.add("")
    
    # Only allow exit when all money is awarded
    if blackjack.moneyAwardedSoFar >= blackjack.moneyToAward:
      messages.add("Press any key to continue...")
    else:
      messages.add("Awarding winnings...")
    
    drawMinigameUI("BLACKJACK", player, messages)
    
    # Only allow exit after money is fully awarded
    if blackjack.moneyAwardedSoFar >= blackjack.moneyToAward and (isKeyPressed(Space) or isKeyPressed(Enter) or isKeyPressed(Escape)):
      blackjack.state = Betting
      blackjack.bet = 0
      blackjack.pulseTimer = 0.0
      return true
  
  return false
