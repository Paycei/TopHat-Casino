import raylib, math, random
import ../utils, ../player, ../ui

type
  RouletteState = enum
   
    Idle, ChoosingBetType, ChoosingBetValue, Anticipation, Spinning, Settling, Result
  
  BetType = enum
    BetNumber, BetRed, BetBlack, BetOdd, BetEven
  
  Roulette* = ref object
    position*: Vector3
    rotation*: float
    spinSpeed*: float
    state*: RouletteState
    selectedNumber*: int
    playerBet*: int
    betType*: BetType
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
    
const
  RED_NUMBERS = [1, 3, 5, 7, 9]
  BLACK_NUMBERS = [2, 4, 6, 8]

proc isWinningBet(betType: BetType, betNumber: int, resultNumber: int): bool =
  case betType:
  of BetNumber:
    return resultNumber == betNumber
  of BetRed:
    return resultNumber in RED_NUMBERS
  of BetBlack:
    return resultNumber in BLACK_NUMBERS
  of BetOdd:
    return resultNumber > 0 and resultNumber mod 2 == 1
  of BetEven:
    return resultNumber > 0 and resultNumber mod 2 == 0

proc calculatePayout(betType: BetType, bet: int): int =
  case betType:
  of BetNumber:
    return bet * 10  # 10x for exact number
  of BetRed, BetBlack, BetOdd, BetEven:
    return bet * 2   # 2x for color/odd/even

proc draw3DNumber(num: int, pos: Vector3, size: float, color: Color) =
  drawSphere(pos, size * 0.8, Color(r: color.r div 2, g: color.g div 2, b: color.b div 2, a: 180))
  let cubeSize = size * 0.15
  
  case num:
  of 0:
    for i in 0..7:
      let angle = i.float * TAU / 8.0
      let x = pos.x + cos(angle) * size * 0.4
      let y = pos.y + sin(angle) * size * 0.4
      drawCube(Vector3(x: x, y: y, z: pos.z), cubeSize, cubeSize, cubeSize, color)
  of 1:
    drawCube(pos, cubeSize * 0.8, size * 0.8, cubeSize, color)
  of 2:
    drawCube(Vector3(x: pos.x, y: pos.y + size * 0.3, z: pos.z), size * 0.5, cubeSize, cubeSize, color)
    drawCube(Vector3(x: pos.x, y: pos.y, z: pos.z), size * 0.5, cubeSize, cubeSize, color)
    drawCube(Vector3(x: pos.x, y: pos.y - size * 0.3, z: pos.z), size * 0.5, cubeSize, cubeSize, color)
  of 3:
    drawCube(Vector3(x: pos.x, y: pos.y + size * 0.3, z: pos.z), size * 0.5, cubeSize, cubeSize, color)
    drawCube(pos, size * 0.5, cubeSize, cubeSize, color)
    drawCube(Vector3(x: pos.x, y: pos.y - size * 0.3, z: pos.z), size * 0.5, cubeSize, cubeSize, color)
  of 4:
    drawCube(Vector3(x: pos.x - size * 0.2, y: pos.y, z: pos.z), cubeSize, size * 0.8, cubeSize, color)
    drawCube(Vector3(x: pos.x + size * 0.2, y: pos.y, z: pos.z), cubeSize, size * 0.8, cubeSize, color)
  of 5:
    drawCube(Vector3(x: pos.x, y: pos.y + size * 0.3, z: pos.z), size * 0.5, cubeSize, cubeSize, color)
    drawCube(pos, size * 0.5, cubeSize, cubeSize, color)
    drawCube(Vector3(x: pos.x, y: pos.y - size * 0.3, z: pos.z), size * 0.5, cubeSize, cubeSize, color)
  of 6:
    for i in 0..5:
      let angle = i.float * TAU / 6.0 - TAU / 12.0
      let x = pos.x + cos(angle) * size * 0.4
      let y = pos.y + sin(angle) * size * 0.4
      drawCube(Vector3(x: x, y: y, z: pos.z), cubeSize, cubeSize, cubeSize, color)
  of 7:
    drawCube(Vector3(x: pos.x, y: pos.y + size * 0.3, z: pos.z), size * 0.5, cubeSize, cubeSize, color)
    drawCube(Vector3(x: pos.x + size * 0.1, y: pos.y, z: pos.z), cubeSize, size * 0.5, cubeSize, color)
  of 8:
    for i in 0..3:
      let angle = i.float * TAU / 4.0
      let x = pos.x + cos(angle) * size * 0.35
      let y1 = pos.y + size * 0.15 + sin(angle) * size * 0.35
      let y2 = pos.y - size * 0.15 + sin(angle) * size * 0.35
      drawCube(Vector3(x: x, y: y1, z: pos.z), cubeSize, cubeSize, cubeSize, color)
      drawCube(Vector3(x: x, y: y2, z: pos.z), cubeSize, cubeSize, cubeSize, color)
  of 9:
    for i in 0..5:
      let angle = i.float * TAU / 6.0 + TAU / 12.0
      let x = pos.x + cos(angle) * size * 0.4
      let y = pos.y + sin(angle) * size * 0.4
      drawCube(Vector3(x: x, y: y, z: pos.z), cubeSize, cubeSize, cubeSize, color)
  else:
    drawSphere(pos, size * 0.5, color)

proc newRoulette*(pos: Vector3): Roulette =
  result = Roulette()
  result.position = pos
  result.rotation = 0.0
  result.spinSpeed = 0.0
  result.state = Idle
  result.selectedNumber = 0
  result.playerBet = 0
  result.betType = BetNumber
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
  let basePos = Vector3(x: roulette.position.x, y: roulette.position.y + wobbleOffset, z: roulette.position.z)
  drawCylinder(basePos, 1.8, 1.8, 0.25, 32, Color(r: 80, g: 40, b: 20, a: 255))
  drawCylinder(basePos, 1.6, 1.6, 0.3, 32, Color(r: 110, g: 60, b: 30, a: 255))
  let ringPos = Vector3(x: basePos.x, y: basePos.y + 0.15, z: basePos.z)
  drawCylinder(ringPos, 1.45, 1.45, 0.1, 32, Color(r: 200, g: 160, b: 80, a: 255))
  drawCylinder(ringPos, 1.35, 1.35, 0.1, 32, Color(r: 120, g: 60, b: 0, a: 255))
  let wheelPos = Vector3(x: ringPos.x, y: ringPos.y + 0.1, z: ringPos.z)
  drawCylinder(wheelPos, 1.2, 1.2, 0.08, 64, Color(r: 60, g: 30, b: 10, a: 255))
  for i in 0..35:
    let angle1 = (i.float / 36.0) * TAU + roulette.rotation
    let angle2 = ((i.float + 1.0) / 36.0) * TAU + roulette.rotation
    
    let number = i mod 10
    var pocketColor: Color
    
    if number == 0:
      pocketColor = Color(r: 0, g: 200, b: 50, a: 255)  # Green for 0
    elif number in RED_NUMBERS:
      pocketColor = Color(r: 220, g: 20, b: 20, a: 255)  # Red
    else:
      pocketColor = Color(r: 30, g: 30, b: 30, a: 255)  # Black

    let rInner = 0.35
    let rOuter = 1.15

    let p1 = Vector3(x: wheelPos.x + cos(angle1) * rInner, y: wheelPos.y + 0.02, z: wheelPos.z + sin(angle1) * rInner)
    let p2 = Vector3(x: wheelPos.x + cos(angle2) * rInner, y: wheelPos.y + 0.02, z: wheelPos.z + sin(angle2) * rInner)
    let p3 = Vector3(x: wheelPos.x + cos(angle2) * rOuter, y: wheelPos.y + 0.02, z: wheelPos.z + sin(angle2) * rOuter)
    let p4 = Vector3(x: wheelPos.x + cos(angle1) * rOuter, y: wheelPos.y + 0.02, z: wheelPos.z + sin(angle1) * rOuter)

    drawTriangle3D(p1, p2, p3, pocketColor)
    drawTriangle3D(p1, p3, p4, pocketColor)
    drawLine3D(p1, p4, Gold)
    drawLine3D(p2, p3, Gold)
  drawCylinder(Vector3(x: wheelPos.x, y: wheelPos.y + 0.08, z: wheelPos.z),
               0.35, 0.1, 0.05, 16, Color(r: 90, g: 50, b: 10, a: 255))
  drawSphere(Vector3(x: wheelPos.x, y: wheelPos.y + 0.12, z: wheelPos.z), 0.12, Gold)
  for i in 0..9:
    let angle = (i.float / 10.0) * TAU + roulette.rotation
    let numPos = Vector3(
      x: wheelPos.x + cos(angle) * 0.9,
      y: wheelPos.y + 0.25,
      z: wheelPos.z + sin(angle) * 0.9
    )

    let isSelected = (i == roulette.selectedNumber) and roulette.state == Result
    var numColor: Color
    
    if i == 0:
      numColor = Color(r: 0, g: 255, b: 100, a: 255)  # Green for 0
    elif i in RED_NUMBERS:
      numColor = Color(r: 255, g: 50, b: 50, a: 255)  # Red numbers
    else:
      numColor = Color(r: 230, g: 230, b: 230, a: 255)  # Black numbers (shown as white)
    
    if isSelected and roulette.flashTimer > 0.0:
      numColor = Gold

    draw3DNumber(i, numPos, 0.2, numColor)

    if isSelected:
      let glowSize = 0.25 + sin(getTime() * 8.0) * 0.05
      drawSphere(numPos, glowSize, Color(r: 255, g: 215, b: 0, a: 100))
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
  of Idle, ChoosingBetType, ChoosingBetValue:
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
      roulette.moneyToAward = 0
      roulette.moneyAwardedSoFar = 0
      roulette.moneyTimer = 0.0
      roulette.anticipationWobble = 0.0
  
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
    
    if roulette.timer > 3.0 and roulette.moneyAwardedSoFar >= roulette.moneyToAward:
      roulette.playerBet = 0
      roulette.betNumber = -1
      roulette.winGlow = 0.0
      roulette.flashTimer = 0.0
      roulette.state = Idle
      roulette.anticipationWobble = 0.0

proc play*(roulette: Roulette, player: Player): bool =
  roulette.update(getFrameTime())
  
  if roulette.state == Idle:
    var messages: seq[string] = @[]
    messages.add("+==========================+")
    messages.add("|      ROULETTE TABLE       |")
    messages.add("+==========================+")
    messages.add("")
    
    if roulette.playerBet == 0:
      messages.add("Choose your bet amount:")
      messages.add("")
      messages.add("+-------------------------+")
      messages.add("| [1] $10    [2] $50      |")
      messages.add("| [3] $100   [4] $200     |")
      messages.add("+-------------------------+")
      messages.add("")
      messages.add("[ESC] Leave table")
      
      if isKeyPressed(One):
        if player.removeMoney(10):
          roulette.playerBet = 10
          roulette.state = ChoosingBetType
        else:
          messages.add("")
          messages.add("⚠ Insufficient funds!")
      elif isKeyPressed(Two):
        if player.removeMoney(50):
          roulette.playerBet = 50
          roulette.state = ChoosingBetType
        else:
          messages.add("")
          messages.add("⚠ Insufficient funds!")
      elif isKeyPressed(Three):
        if player.removeMoney(100):
          roulette.playerBet = 100
          roulette.state = ChoosingBetType
        else:
          messages.add("")
          messages.add("⚠ Insufficient funds!")
      elif isKeyPressed(Four):
        if player.removeMoney(200):
          roulette.playerBet = 200
          roulette.state = ChoosingBetType
        else:
          messages.add("")
          messages.add("⚠ Insufficient funds!")
      elif isKeyPressed(Escape):
        return true
    
    drawMinigameUI("ROULETTE", player, messages)
  
  elif roulette.state == ChoosingBetType:
    var messages: seq[string] = @[]
    messages.add("+==========================+")
    messages.add("|    CHOOSE YOUR BET TYPE   |")
    messages.add("+==========================+")
    messages.add("")
    messages.add("Bet: " & formatMoney(roulette.playerBet))
    messages.add("")
    messages.add("+-------------------------+")
    messages.add("| [1] Number (10x)        |")
    messages.add("| [2] Red (2x)            |")
    messages.add("| [3] Black (2x)          |")
    messages.add("| [4] Odd (2x)            |")
    messages.add("| [5] Even (2x)           |")
    messages.add("+-------------------------+")
    messages.add("")
    messages.add("[ESC] Cancel bet")
    
    if isKeyPressed(One):
      roulette.betType = BetNumber
      roulette.state = ChoosingBetValue
    elif isKeyPressed(Two):
      roulette.betType = BetRed
      roulette.state = Anticipation
      roulette.timer = 0.0
      roulette.moneyAwarded = false
    elif isKeyPressed(Three):
      roulette.betType = BetBlack
      roulette.state = Anticipation
      roulette.timer = 0.0
      roulette.moneyAwarded = false
    elif isKeyPressed(Four):
      roulette.betType = BetOdd
      roulette.state = Anticipation
      roulette.timer = 0.0
      roulette.moneyAwarded = false
    elif isKeyPressed(Five):
      roulette.betType = BetEven
      roulette.state = Anticipation
      roulette.timer = 0.0
      roulette.moneyAwarded = false
    elif isKeyPressed(Escape):
      player.addMoney(roulette.playerBet)
      roulette.playerBet = 0
      roulette.state = Idle
    
    drawMinigameUI("ROULETTE", player, messages)
  
  elif roulette.state == ChoosingBetValue:
    var messages: seq[string] = @[]
    messages.add("+==========================+")
    messages.add("|    PICK YOUR NUMBER       |")
    messages.add("+==========================+")
    messages.add("")
    messages.add("Bet: " & formatMoney(roulette.playerBet) & " on NUMBER")
    messages.add("Payout: 10x your bet!")
    messages.add("")
    messages.add("+-------------------------+")
    messages.add("| [0] Zero                |")
    messages.add("| [1][3][5][7][9] Red     |")
    messages.add("| [2][4][6][8] Black      |")
    messages.add("+-------------------------+")
    messages.add("")
    
    if roulette.betNumber >= 0:
      messages.add("Selected: " & $roulette.betNumber)
      messages.add("[SPACE] Confirm & Spin")
    
    messages.add("[ESC] Back")
    
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
    elif isKeyPressed(Escape):
      roulette.state = ChoosingBetType
      roulette.betNumber = -1
    
    drawMinigameUI("ROULETTE", player, messages)
  
  elif roulette.state == Anticipation:
    var messages: seq[string] = @[]
    messages.add("+==========================+")
    messages.add("|     PLACING BETS...      |")
    messages.add("+==========================+")
    drawMinigameUI("ROULETTE", player, messages)
  
  elif roulette.state == Spinning or roulette.state == Settling:
    var messages: seq[string] = @[]
    
    if roulette.state == Spinning:
      messages.add("+==========================+")
      messages.add("|    WHEEL SPINNING!       |")
      messages.add("+==========================+")
    else:
      messages.add("+==========================+")
      messages.add("|    BALL SETTLING...      |")
      messages.add("+==========================+")
    
    drawMinigameUI("ROULETTE", player, messages)
  
  elif roulette.state == Result:
    var messages: seq[string] = @[]
    
    let isWin = isWinningBet(roulette.betType, roulette.betNumber, roulette.selectedNumber)
    
    if isWin and roulette.flashTimer > 0.0 and (int(roulette.flashTimer * 8.0) mod 2 == 0):
      messages.add("+==========================+")
      messages.add("|      WINNER!!!           |")
      messages.add("+==========================+")
    else:
      messages.add("+==========================+")
      messages.add("|        RESULT            |")
      messages.add("+==========================+")
    
    messages.add("")
    
    var resultColor = "🟢"
    if roulette.selectedNumber in RED_NUMBERS:
      resultColor = "🔴"
    elif roulette.selectedNumber in BLACK_NUMBERS:
      resultColor = "⚫"
    
    messages.add("Number: " & resultColor & " " & $roulette.selectedNumber)
    messages.add("")
    
    case roulette.betType:
    of BetNumber:
      messages.add("Your bet: NUMBER " & $roulette.betNumber)
    of BetRed:
      messages.add("Your bet: 🔴 RED")
    of BetBlack:
      messages.add("Your bet: ⚫ BLACK")
    of BetOdd:
      messages.add("Your bet: 📊 ODD")
    of BetEven:
      messages.add("Your bet: 📈 EVEN")
    
    messages.add("")
    
    if not roulette.moneyAwarded:
      if isWin:
        roulette.moneyToAward = calculatePayout(roulette.betType, roulette.playerBet)
        roulette.flashTimer = 1.5
        messages.add("+-------------------------+")
        messages.add("|  YOU WIN!               |")
        messages.add("|  Won: " & formatMoney(roulette.moneyToAward))
        messages.add("+-------------------------+")
      else:
        roulette.moneyToAward = 0
        messages.add("+-------------------------+")
        messages.add("|  YOU LOSE               |")
        messages.add("|  Lost: " & formatMoney(roulette.playerBet))
        messages.add("+-------------------------+")
      roulette.moneyAwarded = true
    else:
      roulette.moneyTimer += getFrameTime()
      
      if roulette.moneyTimer >= 0.06 and roulette.moneyAwardedSoFar < roulette.moneyToAward:
        roulette.moneyTimer = 0.0
        var increment = if roulette.moneyToAward < 100: 5
                        elif roulette.moneyToAward < 500: 10
                        elif roulette.moneyToAward < 1000: 25
                        else: 50
        increment = min(increment, roulette.moneyToAward - roulette.moneyAwardedSoFar)
        player.addMoney(increment)
        roulette.moneyAwardedSoFar += increment
      
      if isWin:
        messages.add("+-------------------------+")
        messages.add("|  YOU WIN!               |")
        messages.add("|  Won: " & formatMoney(roulette.moneyToAward))
        messages.add("+-------------------------+")
      else:
        messages.add("+-------------------------+")
        messages.add("|  YOU LOSE               |")
        messages.add("|  Lost: " & formatMoney(roulette.playerBet))
        messages.add("+-------------------------+")
    
    messages.add("")
    
    if roulette.moneyAwardedSoFar >= roulette.moneyToAward:
      messages.add("Press any key to continue...")
    else:
      messages.add("💰 Awarding winnings...")
    
    drawMinigameUI("ROULETTE", player, messages)
    
    if roulette.moneyAwardedSoFar >= roulette.moneyToAward and getKeyPressed() != KeyboardKey.Null:
      roulette.playerBet = 0
      roulette.betNumber = -1
      roulette.winGlow = 0.0
      roulette.flashTimer = 0.0
      roulette.state = Idle
      return false
  
  return false