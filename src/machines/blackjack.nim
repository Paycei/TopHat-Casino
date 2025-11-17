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

proc drawFancyTable(tablePos: Vector3, tableBob: float) =
  # Main table surface with rich green felt
  let feltColor = Color(r: 0, g: 100, b: 50, a: 255)
  let edgeColor = Color(r: 139, g: 69, b: 19, a: 255)  # Saddle brown
  let goldTrim = Color(r: 218, g: 165, b: 32, a: 255)
  
  # Draw main felt surface
  drawCube(tablePos, 3.0, 0.2, 2.0, feltColor)
  
  # Draw wooden edge trim
  drawCube(Vector3(x: tablePos.x, y: tablePos.y - 0.08, z: tablePos.z), 
           3.1, 0.08, 2.1, edgeColor)
  
  # Gold decorative trim
  drawCubeWires(Vector3(x: tablePos.x, y: tablePos.y + 0.11, z: tablePos.z), 
                2.85, 0.02, 1.85, goldTrim)
  
  # Betting circles
  let circleY = tablePos.y + 0.11
  
  # Player betting circle
  drawCircle3D(Vector3(x: tablePos.x, y: circleY, z: tablePos.z - 0.5),
               0.3, Vector3(x: 1, y: 0, z: 0), 90.0, goldTrim)
  
  # Dealer position marker
  drawCircle3D(Vector3(x: tablePos.x, y: circleY, z: tablePos.z + 0.5),
               0.25, Vector3(x: 1, y: 0, z: 0), 90.0, Color(r: 200, g: 200, b: 200, a: 100))
  
  # Card position markers (subtle rectangles)
  let markerColor = Color(r: 255, g: 215, b: 0, a: 60)
  
  # Player card areas
  for i in 0..2:
    drawCube(Vector3(x: tablePos.x - 0.6 + i.float * 0.25, y: circleY, z: tablePos.z - 0.5),
             0.2, 0.01, 0.3, markerColor)
  
  # Dealer card areas
  for i in 0..2:
    drawCube(Vector3(x: tablePos.x + 0.6 - i.float * 0.25, y: circleY, z: tablePos.z + 0.5),
             0.2, 0.01, 0.3, markerColor)
  
  # Decorative corner designs
  for ix in [-1, 1]:
    for iz in [-1, 1]:
      let cornerPos = Vector3(
        x: tablePos.x + ix.float * 1.3,
        y: circleY,
        z: tablePos.z + iz.float * 0.85
      )
      drawCylinder(cornerPos, 0.08, 0.08, 0.01, 8, goldTrim)

proc drawTableLegs(tablePos: Vector3) =
  let darkWood = Color(r: 101, g: 67, b: 33, a: 255)
  let legBrass = Color(r: 181, g: 166, b: 66, a: 255)
  
  for ix in [-1, 1]:
    for iz in [-1, 1]:
      let legPos = Vector3(
        x: tablePos.x + ix.float * 1.3,
        y: tablePos.y - 0.6,
        z: tablePos.z + iz.float * 0.8
      )
      # Main leg
      drawCube(legPos, 0.15, 1.0, 0.15, darkWood)
      # Brass foot cap
      drawCylinder(Vector3(x: legPos.x, y: legPos.y - 0.52, z: legPos.z), 
                   0.09, 0.09, 0.04, 8, legBrass)

proc drawChipStack(tablePos: Vector3, chipStackHeight: float) =
  if chipStackHeight <= 0.0:
    return
  
  let chipBasePos = Vector3(
    x: tablePos.x,
    y: tablePos.y + 0.11,  # Start at table surface
    z: tablePos.z - 0.5    # Center of betting circle
  )
  
  let chips = int(chipStackHeight)
  let goldChip = Color(r: 255, g: 215, b: 0, a: 255)
  let chipEdge = Color(r: 200, g: 160, b: 0, a: 255)
  
  for i in 0..<chips:
    # Stack chips DOWNWARD (decreasing y)
    let stackPos = Vector3(
      x: chipBasePos.x,
      y: chipBasePos.y - i.float * 0.05,  # Subtract to go down
      z: chipBasePos.z
    )
    
    # Main chip body
    drawCylinder(stackPos, 0.15, 0.15, 0.04, 16, goldChip)
    
    # Edge detailing
    drawCylinderWires(stackPos, 0.15, 0.15, 0.04, 16, chipEdge)
    
    # Add center marking on top chip
    if i == 0:
      drawCylinder(Vector3(x: stackPos.x, y: stackPos.y + 0.021, z: stackPos.z),
                   0.06, 0.06, 0.005, 8, Color(r: 139, g: 0, b: 0, a: 255))

proc drawCard3D(pos: Vector3, card: Card, isHidden: bool, isPulsing: bool, flipProgress: float) =
  let pulse = if isPulsing: sin(getTime() * 10.0) * 0.05 + 1.0 else: 1.0
  let flipScale = if isHidden: abs(cos(flipProgress * PI)) else: 1.0
  
  # Card colors
  let cardWhite = Color(r: 245, g: 245, b: 245, a: 255)
  let cardRed = Color(r: 200, g: 0, b: 0, a: 255)
  let cardBlack = Color(r: 20, g: 20, b: 20, a: 255)
  let cardBack = Color(r: 180, g: 0, b: 0, a: 255)
  let goldEdge = Color(r: 218, g: 165, b: 32, a: 255)
  
  # Determine card appearance
  let cardColor = if isHidden: cardBack else: cardWhite
  let suitColor = if card.suit in ["♥", "♦"]: cardRed else: cardBlack
  
  # Draw main card body with scaled width for flip effect
  drawCube(pos, 0.2 * flipScale * pulse, 0.02, 0.30 * pulse, cardColor)
  
  # Draw card border/edge
  if not isHidden and flipScale > 0.3:
    drawCubeWires(pos, 0.21 * flipScale * pulse, 0.021, 0.31 * pulse, Color(r: 200, g: 200, b: 200, a: 255))
    
    # Draw suit indicator (simplified 3D representation)
    let suitPos = Vector3(x: pos.x, y: pos.y + 0.011, z: pos.z)
    drawCube(suitPos, 0.08 * flipScale, 0.005, 0.08, suitColor)
  
  # Pulsing gold outline for winning cards
  if isPulsing:
    drawCubeWires(pos, 0.21 * flipScale * pulse, 0.025, 0.31 * pulse, goldEdge)

proc draw3D*(blackjack: Blackjack) =
  pushMatrix()
  translatef(blackjack.position.x, blackjack.position.y, blackjack.position.z)
  rotatef(180, 0, 1, 0)
  translatef(-blackjack.position.x, -blackjack.position.y, -blackjack.position.z)
  
  # Calculate gentle bobbing motion
  let tableBob = sin(getTime() * 0.5) * 0.01
  let tablePos = Vector3(
    x: blackjack.position.x,
    y: blackjack.position.y + 0.5 + tableBob,
    z: blackjack.position.z
  )
  
  # Draw the enhanced table
  drawFancyTable(tablePos, tableBob)
  drawTableLegs(tablePos)
  
  # Draw chip stack (fixed to go downward)
  drawChipStack(tablePos, blackjack.chipStackHeight)
  
  # Draw player cards
  let isPulsing = blackjack.pulseTimer > 0.0
  for i, card in blackjack.playerHand:
    let slideIn = 1.0 - card.slideOffset
    let cardVisPos = Vector3(
      x: tablePos.x - 0.8 + i.float * 0.20 + card.slideOffset * -4.0,
      y: tablePos.y + 0.15 + (1.0 - slideIn) * 0.5,
      z: tablePos.z - 0.5
    )
    drawCard3D(cardVisPos, card, false, isPulsing, 0.0)
  
  # Draw dealer cards
  for i, card in blackjack.dealerHand:
    let slideIn = 1.0 - card.slideOffset
    let isHidden = i == 1 and not blackjack.dealerRevealed
    
    let cardVisPos = Vector3(
      x: tablePos.x + 0.8 - i.float * 0.15 + card.slideOffset * 4.0,
      y: tablePos.y + 0.15 + (1.0 - slideIn) * 0.5,
      z: tablePos.z + 0.5
    )
    
    drawCard3D(cardVisPos, card, isHidden, false, card.flipProgress)
  
  popMatrix()

proc update*(blackjack: Blackjack, deltaTime: float) =
  # Animate card sliding
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
    # Animate card flip
    if not blackjack.dealerRevealed and card.flipProgress < 1.0:
      card.flipProgress += deltaTime * 2.0
      if card.flipProgress > 1.0:
        card.flipProgress = 1.0
  
  # Animate chip stack height
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
  
  # Update pulse timer for winning animation
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
    if blackjack.moneyAwardedSoFar >= blackjack.moneyToAward:
      messages.add("Press any key to continue...")
    else:
      messages.add("Awarding winnings...")
    
    drawMinigameUI("BLACKJACK", player, messages)
    if blackjack.moneyAwardedSoFar >= blackjack.moneyToAward and getKeyPressed() != KeyboardKey.Null:
      blackjack.state = Betting
      blackjack.bet = 0
      blackjack.pulseTimer = 0.0
      return false
  
  return false
