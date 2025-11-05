import raylib, math, random
import ../utils, ../player, ../ui

type
  SlotState = enum
    Idle, Spinning, Result
  
  Slots* = ref object
    position*: Vector3
    reels*: array[3, int]
    targetReels*: array[3, int]
    spinProgress*: array[3, float]
    state*: SlotState
    bet*: int
    timer*: float
    moneyAwarded*: bool
    moneyToAward*: int
    moneyAwardedSoFar*: int

const SYMBOLS = ["7", "BAR", "🍒", "🍋", "⭐"]

proc newSlots*(pos: Vector3): Slots =
  result = Slots()
  result.position = pos
  result.reels = [0, 0, 0]
  result.targetReels = [0, 0, 0]
  result.spinProgress = [0.0, 0.0, 0.0]
  result.state = Idle
  result.bet = 0
  result.timer = 0.0
  result.moneyAwarded = false
  result.moneyToAward = 0
  result.moneyAwardedSoFar = 0

proc draw3D*(slots: Slots) =
  # Machine body
  let bodyPos = Vector3(
    x: slots.position.x,
    y: slots.position.y + 1.0,
    z: slots.position.z
  )
  drawCube(bodyPos, 2.0, 2.0, 0.5, DarkGray)
  drawCubeWires(bodyPos, 2.0, 2.0, 0.5, Gold)
  
  # Screen area (3 reels)
  for i in 0..2:
    let reelPos = Vector3(
      x: bodyPos.x - 0.6 + i.float * 0.6,
      y: bodyPos.y + 0.3,
      z: bodyPos.z - 0.26
    )
    drawCube(reelPos, 0.5, 0.8, 0.02, Black)
    drawCubeWires(reelPos, 0.5, 0.8, 0.02, Yellow)
  
  # Base
  drawCube(slots.position, 2.2, 0.2, 0.7, Maroon)
  
  # Handle on the right
  let handleBase = Vector3(
    x: bodyPos.x + 1.1,
    y: bodyPos.y - 0.3,
    z: bodyPos.z
  )
  drawCylinder(handleBase, 0.05, 0.05, 0.6, 8, Red)
  drawSphere(
    Vector3(x: handleBase.x, y: handleBase.y + 0.6, z: handleBase.z),
    0.15, Red
  )

proc update*(slots: Slots, deltaTime: float) =
  if slots.state == Spinning:
    var allStopped = true
    for i in 0..2:
      if slots.spinProgress[i] < 1.0:
        slots.spinProgress[i] += deltaTime * (0.8 + i.float * 0.3)
        if slots.spinProgress[i] >= 1.0:
          slots.spinProgress[i] = 1.0
          slots.reels[i] = slots.targetReels[i]
        allStopped = false
    
    if allStopped:
      slots.state = Result
      slots.timer = 0.0

proc play*(slots: Slots, player: Player): bool =
  if slots.state == Idle:
    var messages: seq[string] = @[]
    messages.add("=== SLOT MACHINE ===")
    messages.add("")
    
    if slots.bet == 0:
      messages.add("Choose your bet:")
      messages.add("")
      messages.add("[1] $5   [2] $25   [3] $50")
      messages.add("")
      messages.add("Win conditions:")
      messages.add("3 same symbols: 10x bet")
      messages.add("2 same symbols: 2x bet")
      messages.add("[ESC] Back")
      
      if isKeyPressed(One):
        if player.removeMoney(5):
          slots.bet = 5
        else:
          messages.add("")
          messages.add("Not enough money!")
      elif isKeyPressed(Two):
        if player.removeMoney(25):
          slots.bet = 25
        else:
          messages.add("")
          messages.add("Not enough money!")
      elif isKeyPressed(Three):
        if player.removeMoney(50):
          slots.bet = 50
        else:
          messages.add("")
          messages.add("Not enough money!")
    else:
      messages.add("Bet: " & formatMoney(slots.bet))
      messages.add("")
      messages.add("Current reels:")
      messages.add(SYMBOLS[slots.reels[0]] & " | " & SYMBOLS[slots.reels[1]] & " | " & SYMBOLS[slots.reels[2]])
      messages.add("")
      messages.add("[SPACE] Pull lever!")
      messages.add("[ESC] Cancel bet")
      
      if isKeyPressed(Space):
        slots.state = Spinning
        slots.spinProgress = [0.0, 0.0, 0.0]
        slots.moneyAwarded = false
        slots.moneyToAward = 0
        slots.moneyAwardedSoFar = 0
        for i in 0..2:
          slots.targetReels[i] = rand(SYMBOLS.len - 1)
    
    drawMinigameUI("SLOTS", player, messages)
    
    if isKeyPressed(Escape):
      if slots.bet > 0:
        player.addMoney(slots.bet)
      slots.bet = 0
      return true
  
  elif slots.state == Spinning:
    slots.update(getFrameTime())  # Call update to handle spin logic
    var messages: seq[string] = @[]
    messages.add("=== SPINNING ===")
    messages.add("")
    
    # Show spinning animation
    var display = ""
    for i in 0..2:
      if slots.spinProgress[i] < 1.0:
        let animIdx = (getTime().int div 100) mod SYMBOLS.len
        display &= SYMBOLS[animIdx]
      else:
        display &= SYMBOLS[slots.reels[i]]
      if i < 2:
        display &= " | "
    
    messages.add(display)
    drawMinigameUI("SLOTS", player, messages)
  
  elif slots.state == Result:
    var messages: seq[string] = @[]
    messages.add("=== RESULT ===")
    messages.add("")
    messages.add(SYMBOLS[slots.reels[0]] & " | " & SYMBOLS[slots.reels[1]] & " | " & SYMBOLS[slots.reels[2]])
    messages.add("")
    
    if not slots.moneyAwarded:
      # Check win and determine total winnings
      let r0 = slots.reels[0]
      let r1 = slots.reels[1]
      let r2 = slots.reels[2]
      
      if r0 == r1 and r1 == r2:
        # Three of a kind
        slots.moneyToAward = slots.bet * 10
        messages.add("JACKPOT! THREE OF A KIND!")
        messages.add("Won: " & formatMoney(slots.moneyToAward))
      elif r0 == r1 or r1 == r2 or r0 == r2:
        # Two of a kind
        slots.moneyToAward = slots.bet * 2
        messages.add("WIN! TWO OF A KIND!")
        messages.add("Won: " & formatMoney(slots.moneyToAward))
      else:
        slots.moneyToAward = 0
        messages.add("NO MATCH")
        messages.add("Lost: " & formatMoney(slots.bet))
      slots.moneyAwarded = true
    else:
      # Award money incrementally
      if slots.moneyAwardedSoFar < slots.moneyToAward:
        let increment = min(10, slots.moneyToAward - slots.moneyAwardedSoFar)
        player.addMoney(increment)
        slots.moneyAwardedSoFar += increment
      
      # Show same messages without recalculating
      let r0 = slots.reels[0]
      let r1 = slots.reels[1]
      let r2 = slots.reels[2]
      
      if r0 == r1 and r1 == r2:
        messages.add("JACKPOT! THREE OF A KIND!")
        messages.add("Won: " & formatMoney(slots.moneyToAward))
      elif r0 == r1 or r1 == r2 or r0 == r2:
        messages.add("WIN! TWO OF A KIND!")
        messages.add("Won: " & formatMoney(slots.moneyToAward))
      else:
        messages.add("NO MATCH")
        messages.add("Lost: " & formatMoney(slots.bet))
    
    messages.add("")
    messages.add("Press any key to continue...")
    
    drawMinigameUI("SLOTS", player, messages)
    
    if isKeyPressed(Space) or isKeyPressed(Enter) or isKeyPressed(Escape):
      slots.bet = 0
      slots.state = Idle
      return true
  
  return false