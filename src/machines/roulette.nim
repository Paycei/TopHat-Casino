import raylib, math, random
import ../utils, ../player, ../ui

type
  RouletteState = enum
    Idle, Spinning, Result
  
  Roulette* = ref object
    position*: Vector3
    rotation*: float
    spinSpeed*: float
    state*: RouletteState
    selectedNumber*: int
    playerBet*: int
    betNumber*: int
    timer*: float

proc newRoulette*(pos: Vector3): Roulette =
  result = Roulette()
  result.position = pos
  result.rotation = 0.0
  result.spinSpeed = 0.0
  result.state = Idle
  result.selectedNumber = 0
  result.playerBet = 0
  result.betNumber = -1
  result.timer = 0.0

proc draw3D*(roulette: Roulette) =
  # Base table
  drawCylinder(roulette.position, 1.5, 1.5, 0.1, 16, DarkBrown)
  
  # Roulette wheel
  let wheelPos = Vector3(
    x: roulette.position.x,
    y: roulette.position.y + 0.15,
    z: roulette.position.z
  )
  
  # Outer rim
  drawCylinder(wheelPos, 1.2, 1.2, 0.1, 32, DarkGray)
  
  # Inner spinning part with rotation
  let spinPos = Vector3(x: wheelPos.x, y: wheelPos.y + 0.05, z: wheelPos.z)
  drawCylinder(spinPos, 1.0, 1.0, 0.01, 32, Red)
  
  # Center pin
  drawCylinder(
    Vector3(x: wheelPos.x, y: wheelPos.y + 0.1, z: wheelPos.z),
    0.1, 0.1, 0.3, 8, Gold
  )
  
  # Numbers indicator (simplified - draw spheres around)
  for i in 0..11:
    let angle = (i.float / 12.0) * PI * 2.0 + roulette.rotation
    let numPos = Vector3(
      x: wheelPos.x + cos(angle) * 0.8,
      y: wheelPos.y + 0.15,
      z: wheelPos.z + sin(angle) * 0.8
    )
    let color = if i mod 2 == 0: Red else: Black
    drawSphere(numPos, 0.08, color)

proc update*(roulette: Roulette, deltaTime: float) =
  case roulette.state:
  of Idle:
    discard
  of Spinning:
    roulette.rotation += roulette.spinSpeed * deltaTime
    roulette.spinSpeed *= 0.98  # Deceleration
    roulette.timer += deltaTime
    
    if roulette.spinSpeed < 0.5 or roulette.timer > 4.0:
      roulette.state = Result
      roulette.selectedNumber = rand(36)
      roulette.timer = 0.0
  of Result:
    roulette.timer += deltaTime
    if roulette.timer > 3.0:
      roulette.state = Idle

proc play*(roulette: Roulette, player: Player): bool =
  # Returns true when game is finished
  if roulette.state == Idle:
    var messages: seq[string] = @[]
    messages.add("=== ROULETTE ===")
    messages.add("")
    
    if roulette.playerBet == 0:
      messages.add("Choose your bet amount:")
      messages.add("")
      messages.add("[1] $10   [2] $50   [3] $100")
      messages.add("[ESC] Back")
      
      if isKeyPressed(One):
        if player.removeMoney(10):
          roulette.playerBet = 10
        else:
          messages.add("Not enough money!")
      elif isKeyPressed(Two):
        if player.removeMoney(50):
          roulette.playerBet = 50
        else:
          messages.add("Not enough money!")
      elif isKeyPressed(Three):
        if player.removeMoney(100):
          roulette.playerBet = 100
        else:
          messages.add("Not enough money!")
    else:
      messages.add("Bet placed: " & formatMoney(roulette.playerBet))
      messages.add("")
      messages.add("Pick a number (0-9):")
      messages.add("")
      messages.add("Number keys 0-9 to choose")
      messages.add("[SPACE] Spin")
      messages.add("[ESC] Cancel")
      
      if roulette.betNumber >= 0:
        messages.add("")
        messages.add("Selected: " & $roulette.betNumber)
      
      # Number selection
      if isKeyPressed(Zero): roulette.betNumber = 0
      elif isKeyPressed(One): roulette.betNumber = 1
      elif isKeyPressed(Two): roulette.betNumber = 2
      elif isKeyPressed(Three): roulette.betNumber = 3
      elif isKeyPressed(Four): roulette.betNumber = 4
      elif isKeyPressed(Five): roulette.betNumber = 5
      elif isKeyPressed(Six): roulette.betNumber = 6
      elif isKeyPressed(Seven): roulette.betNumber = 7
      elif isKeyPressed(Eight): roulette.betNumber = 8
      elif isKeyPressed(Nine): roulette.betNumber = 9
      
      if isKeyPressed(Space) and roulette.betNumber >= 0:
        roulette.state = Spinning
        roulette.spinSpeed = 15.0 + rand(10.0)
        roulette.timer = 0.0
    
    drawMinigameUI("ROULETTE", player, messages)
    
    if isKeyPressed(Escape):
      if roulette.playerBet > 0:
        player.addMoney(roulette.playerBet)
      roulette.playerBet = 0
      roulette.betNumber = -1
      return true
  
  elif roulette.state == Spinning:
    var messages: seq[string] = @[]
    messages.add("=== SPINNING ===")
    messages.add("")
    messages.add("The wheel is spinning...")
    drawMinigameUI("ROULETTE", player, messages)
  
  elif roulette.state == Result:
    var messages: seq[string] = @[]
    messages.add("=== RESULT ===")
    messages.add("")
    messages.add("Winning number: " & $roulette.selectedNumber)
    messages.add("Your number: " & $roulette.betNumber)
    messages.add("")
    
    if roulette.selectedNumber == roulette.betNumber:
      let winnings = roulette.playerBet * 10
      player.addMoney(winnings)
      messages.add("YOU WIN!")
      messages.add("Won: " & formatMoney(winnings))
    else:
      messages.add("YOU LOSE")
      messages.add("Lost: " & formatMoney(roulette.playerBet))
    
    messages.add("")
    messages.add("Press any key to continue...")
    
    drawMinigameUI("ROULETTE", player, messages)
    
    if isKeyPressed(Space) or isKeyPressed(Enter) or isKeyPressed(Escape):
      roulette.playerBet = 0
      roulette.betNumber = -1
      return true
  
  return false