import raylib, math, random
import ../utils, ../player, ../ui

type
  RouletteState = enum
    Idle, Anticipation, Spinning, Settling, Result
  
  Roulette* = ref object
    position*: Vector3
    rotation*: float
    spinSpeed*: float
    state*: RouletteState
    selectedNumber*: int
    playerBet*: int
    betNumber*: int
    timer*: float
    moneyAwarded*: bool
    moneyToAward*: int
    moneyAwardedSoFar*: int
    moneyTimer*: float
    ballAngle*: float
    ballSpeed*: float
    ballRadius*: float
    anticipationWobble*: float
    flashTimer*: float
    winGlow*: float
    bounceCount*: int

proc easeOutQuart(t: float): float =
  let t2 = 1.0 - t
  return 1.0 - t2 * t2 * t2 * t2

proc easeInQuart(t: float): float =
  return t * t * t * t

proc draw3DNumber(num: int, pos: Vector3, size: float, color: Color) =
  # Draw simple 3D numbers using cubes
  let segments = case num:
    of 0: @[(0.0, 1.0), (0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]  # O shape
    of 1: @[(1.0, 0.0), (1.0, 1.0)]  # I shape
    of 2: @[(0.0, 1.0), (1.0, 1.0), (1.0, 0.5), (0.0, 0.5), (0.0, 0.0), (1.0, 0.0)]  # S shape
    of 3: @[(0.0, 1.0), (1.0, 1.0), (1.0, 0.5), (0.0, 0.5), (1.0, 0.5), (1.0, 0.0), (0.0, 0.0)]
    of 4: @[(0.0, 1.0), (0.0, 0.5), (1.0, 0.5), (1.0, 1.0), (1.0, 0.0)]
    of 5: @[(1.0, 1.0), (0.0, 1.0), (0.0, 0.5), (1.0, 0.5), (1.0, 0.0), (0.0, 0.0)]
    of 6: @[(1.0, 1.0), (0.0, 1.0), (0.0, 0.0), (1.0, 0.0), (1.0, 0.5), (0.0, 0.5)]
    of 7: @[(0.0, 1.0), (1.0, 1.0), (1.0, 0.0)]
    of 8: @[(0.0, 0.5), (0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0), (0.0, 0.5), (1.0, 0.5)]
    of 9: @[(1.0, 0.0), (1.0, 1.0), (0.0, 1.0), (0.0, 0.5), (1.0, 0.5)]
    else: @[]
  
  # Draw lines as thin cubes
  for i in 0..<segments.len - 1:
    let p1 = segments[i]
    let p2 = segments[i + 1]
    
    let x1 = pos.x + (p1[0].float - 0.5) * size
    let y1 = pos.y + (p1[1].float - 0.5) * size
    let x2 = pos.x + (p2[0].float - 0.5) * size
    let y2 = pos.y + (p2[1].float - 0.5) * size
    
    let midX = (x1 + x2) / 2.0
    let midY = (y1 + y2) / 2.0
    let len = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
    
    if len > 0.01:
      drawCube(Vector3(x: midX, y: midY, z: pos.z), size * 0.15, len, size * 0.1, color)

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
  result.moneyAwarded = false
  result.moneyToAward = 0
  result.moneyAwardedSoFar = 0
  result.moneyTimer = 0.0
  result.ballAngle = 0.0
  result.ballSpeed = 0.0
  result.ballRadius = 1.0
  result.anticipationWobble = 0.0
  result.flashTimer = 0.0
  result.winGlow = 0.0
  result.bounceCount = 0

proc draw3D*(roulette: Roulette) =
  let wobbleOffset = sin(roulette.anticipationWobble * PI * 8.0) * 0.02

  # --- Base ---
  let basePos = Vector3(x: roulette.position.x, y: roulette.position.y + wobbleOffset, z: roulette.position.z)
  drawCylinder(basePos, 1.8, 1.8, 0.25, 32, Color(r: 80, g: 40, b: 20, a: 255)) # madera
  drawCylinder(basePos, 1.6, 1.6, 0.3, 32, Color(r: 110, g: 60, b: 30, a: 255)) # borde superior

  # --- Aro metálico ---
  let ringPos = Vector3(x: basePos.x, y: basePos.y + 0.15, z: basePos.z)
  drawCylinder(ringPos, 1.45, 1.45, 0.1, 32, Color(r: 200, g: 160, b: 80, a: 255)) # dorado
  drawCylinder(ringPos, 1.35, 1.35, 0.1, 32, Color(r: 120, g: 60, b: 0, a: 255))  # sombra interior

  # --- Rueda ---
  let wheelPos = Vector3(x: ringPos.x, y: ringPos.y + 0.1, z: ringPos.z)
  drawCylinder(wheelPos, 1.2, 1.2, 0.08, 64, Color(r: 60, g: 30, b: 10, a: 255)) # superficie oscura

  # --- Secciones rojo/negro/verde ---
  for i in 0..35:
    let angle1 = (i.float / 36.0) * TAU + roulette.rotation
    let angle2 = ((i.float + 1.0) / 36.0) * TAU + roulette.rotation

    var color: Color
    if i == 0:
      color = Color(r: 0, g: 180, b: 0, a: 255) # verde 0
    elif i mod 2 == 0:
      color = Color(r: 180, g: 0, b: 0, a: 255) # rojo
    else:
      color = Color(r: 20, g: 20, b: 20, a: 255) # negro

    let rInner = 0.35
    let rOuter = 1.15

    let p1 = Vector3(x: wheelPos.x + cos(angle1) * rInner, y: wheelPos.y, z: wheelPos.z + sin(angle1) * rInner)
    let p2 = Vector3(x: wheelPos.x + cos(angle2) * rInner, y: wheelPos.y, z: wheelPos.z + sin(angle2) * rInner)
    let p3 = Vector3(x: wheelPos.x + cos(angle2) * rOuter, y: wheelPos.y + 0.01, z: wheelPos.z + sin(angle2) * rOuter)
    let p4 = Vector3(x: wheelPos.x + cos(angle1) * rOuter, y: wheelPos.y + 0.01, z: wheelPos.z + sin(angle1) * rOuter)

    drawTriangle3D(p1, p2, p3, color)
    drawTriangle3D(p1, p3, p4, color)

  # --- Centro cóncavo ---
  drawCylinder(Vector3(x: wheelPos.x, y: wheelPos.y + 0.08, z: wheelPos.z),
               0.35, 0.1, 0.05, 16, Color(r: 90, g: 50, b: 10, a: 255))
  drawSphere(Vector3(x: wheelPos.x, y: wheelPos.y + 0.12, z: wheelPos.z), 0.12, Gold)

  # --- Números alrededor ---
  for i in 0..9:
    let angle = (i.float / 10.0) * TAU + roulette.rotation
    let numPos = Vector3(
      x: wheelPos.x + cos(angle) * 0.9,
      y: wheelPos.y + 0.25,
      z: wheelPos.z + sin(angle) * 0.9
    )

    let isSelected = (i == roulette.selectedNumber) and roulette.state == Result
    var numColor = if i == 0: Green else: White
    if isSelected and roulette.flashTimer > 0.0:
      numColor = Gold

    draw3DNumber(i, numPos, 0.2, numColor)

    if isSelected:
      let glowSize = 0.25 + sin(getTime() * 8.0) * 0.05
      drawSphere(numPos, glowSize, Color(r: 255, g: 215, b: 0, a: 100))

  # --- Bola ---
  if roulette.state == Spinning or roulette.state == Settling:
    let ballHeight = wheelPos.y + 0.25 + sin(roulette.ballAngle * 3.0) * 0.03
    let ballPos = Vector3(
      x: wheelPos.x + cos(roulette.ballAngle) * roulette.ballRadius,
      y: ballHeight,
      z: wheelPos.z + sin(roulette.ballAngle) * roulette.ballRadius
    )
    drawSphere(ballPos, 0.06, Color(r: 250, g: 250, b: 250, a: 255))
    drawSphere(Vector3(x: ballPos.x, y: ballPos.y - 0.02, z: ballPos.z), 0.06, Color(r: 0, g: 0, b: 0, a: 60))


proc update*(roulette: Roulette, deltaTime: float) =
  case roulette.state:
  of Idle:
    discard
  
  of Anticipation:
    roulette.anticipationWobble += deltaTime * 2.0
    roulette.timer += deltaTime
    
    if roulette.timer >= 1.0:
      roulette.state = Spinning
      roulette.timer = 0.0
      roulette.spinSpeed = 8.0 + rand(4.0)
      roulette.ballSpeed = 18.0 + rand(6.0)
      roulette.ballRadius = 1.05
      roulette.ballAngle = rand(PI * 2.0)
      roulette.bounceCount = 0
  
  of Spinning:
    roulette.rotation += roulette.spinSpeed * deltaTime
    roulette.ballAngle += roulette.ballSpeed * deltaTime
    
    let decayRate = 0.96
    roulette.spinSpeed *= decayRate
    roulette.ballSpeed *= decayRate
    
    roulette.timer += deltaTime
    
    if roulette.timer > 2.0 and roulette.ballSpeed < 8.0:
      roulette.state = Settling
      roulette.timer = 0.0
  
  of Settling:
    roulette.rotation += roulette.spinSpeed * deltaTime
    roulette.spinSpeed *= 0.98
    
    roulette.ballSpeed *= 0.94
    roulette.ballAngle += roulette.ballSpeed * deltaTime
    
    roulette.ballRadius -= deltaTime * 0.3
    if roulette.ballRadius < 0.85:
      roulette.ballRadius = 0.85
    
    if roulette.ballSpeed < 3.0 and roulette.bounceCount < 5:
      if int(roulette.timer * 10.0) mod 15 == 0:
        roulette.ballSpeed += rand(1.0) + 0.5
        roulette.bounceCount += 1
    
    roulette.timer += deltaTime
    
    if roulette.ballSpeed < 0.5 or roulette.timer > 5.0:
      roulette.state = Result
      let normalizedAngle = (roulette.ballAngle mod (PI * 2.0)) / (PI * 2.0)
      roulette.selectedNumber = int(normalizedAngle * 10.0) mod 10
      roulette.timer = 0.0
      
      if roulette.selectedNumber == roulette.betNumber:
        roulette.flashTimer = 1.0
  
  of Result:
    roulette.timer += deltaTime
    
    if roulette.flashTimer > 0.0:
      roulette.flashTimer -= deltaTime
    
    if roulette.selectedNumber == roulette.betNumber:
      roulette.winGlow = (sin(getTime() * 6.0) + 1.0) * 0.5
    else:
      roulette.winGlow = 0.0
    
    if roulette.timer > 3.0:
      roulette.state = Idle
      roulette.anticipationWobble = 0.0

proc play*(roulette: Roulette, player: Player): bool =
  roulette.update(getFrameTime())
  
  if roulette.state == Idle:
    var messages: seq[string] = @[]
    messages.add("=== ROULETTE ===")
    messages.add("")
    
    if roulette.playerBet == 0:
      messages.add("Choose your bet:")
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
      elif isKeyPressed(Escape):
        return true
    else:
      messages.add("Bet: " & formatMoney(roulette.playerBet))
      messages.add("")
      messages.add("Pick a number (0-9):")
      messages.add("")
      messages.add("[0-9] Choose   [SPACE] Spin")
      messages.add("[ESC] Cancel")
      
      if roulette.betNumber >= 0:
        messages.add("")
        messages.add("Selected: " & $roulette.betNumber)
      
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
        roulette.state = Anticipation
        roulette.timer = 0.0
        roulette.moneyAwarded = false
        roulette.moneyToAward = 0
        roulette.moneyAwardedSoFar = 0
        roulette.moneyTimer = 0.0
        roulette.anticipationWobble = 0.0
    
    drawMinigameUI("ROULETTE", player, messages)
    
    if isKeyReleased(Escape):
      if roulette.playerBet > 0:
        player.addMoney(roulette.playerBet)
      roulette.playerBet = 0
      roulette.betNumber = -1
      return true
  
  elif roulette.state == Anticipation:
    var messages: seq[string] = @[]
    messages.add("=== GET READY ===")
    drawMinigameUI("ROULETTE", player, messages)
  
  elif roulette.state == Spinning or roulette.state == Settling:
    var messages: seq[string] = @[]
    
    if roulette.state == Spinning:
      messages.add("=== SPINNING ===")
    else:
      messages.add("=== SETTLING ===")
    
    drawMinigameUI("ROULETTE", player, messages)
  
  elif roulette.state == Result:
    var messages: seq[string] = @[]
    
    if roulette.flashTimer > 0.0 and (int(roulette.flashTimer * 8.0) mod 2 == 0):
      messages.add("=== 🎰 WINNER!!! 🎰 ===")
    else:
      messages.add("=== RESULT ===")
    
    messages.add("")
    messages.add("Number: " & $roulette.selectedNumber)
    messages.add("Your bet: " & $roulette.betNumber)
    messages.add("")
    
    if not roulette.moneyAwarded:
      if roulette.selectedNumber == roulette.betNumber:
        roulette.moneyToAward = roulette.playerBet * 10
        messages.add("🎉 YOU WIN!")
        messages.add("Won: " & formatMoney(roulette.moneyToAward))
      else:
        roulette.moneyToAward = 0
        messages.add("💔 YOU LOSE")
        messages.add("Lost: " & formatMoney(roulette.playerBet))
      roulette.moneyAwarded = true
    else:
      roulette.moneyTimer += getFrameTime()
      
      if roulette.moneyTimer >= 0.06 and roulette.moneyAwardedSoFar < roulette.moneyToAward:
        roulette.moneyTimer = 0.0
        
        var increment: int
        if roulette.moneyToAward < 100:
          increment = 5
        elif roulette.moneyToAward < 500:
          increment = 10
        elif roulette.moneyToAward < 1000:
          increment = 25
        else:
          increment = 50
        
        increment = min(increment, roulette.moneyToAward - roulette.moneyAwardedSoFar)
        player.addMoney(increment)
        roulette.moneyAwardedSoFar += increment
      
      if roulette.selectedNumber == roulette.betNumber:
        messages.add("🎉 YOU WIN!")
        messages.add("Won: " & formatMoney(roulette.moneyToAward))
      else:
        messages.add("💔 YOU LOSE")
        messages.add("Lost: " & formatMoney(roulette.playerBet))
    
    messages.add("")
    
    if roulette.moneyAwardedSoFar >= roulette.moneyToAward:
      messages.add("Press any key to continue...")
    else:
      messages.add("Awarding winnings...")
    
    drawMinigameUI("ROULETTE", player, messages)
    
    if roulette.moneyAwardedSoFar >= roulette.moneyToAward and (isKeyPressed(Space) or isKeyPressed(Enter) or isKeyPressed(Escape)):
      roulette.playerBet = 0
      roulette.betNumber = -1
      roulette.winGlow = 0.0
      roulette.flashTimer = 0.0
      return true
  
  return false