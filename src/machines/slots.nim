import raylib, rlgl, math, random
import ../utils, ../player, ../ui

type
  SlotState = enum
    Idle, LeverPull, Spinning, Result
  
  Slots* = ref object
    position*: Vector3
    reels*: array[3, array[3, int]]  # 3 columns x 3 rows
    targetReels*: array[3, array[3, int]]
    spinProgress*: array[3, float]
    reelOffset*: array[3, float]
    state*: SlotState
    bet*: int
    timer*: float
    moneyAwarded*: bool
    moneyToAward*: int
    moneyAwardedSoFar*: int
    moneyTimer*: float
    leverAngle*: float
    screenShake*: float
    winGlow*: float
    anticipation*: float
    flashTimer*: float
    particleTimer*: float
    particles*: seq[tuple[x, y, life: float]]
    symbolRotation*: array[3, float]  # Add rotation for each reel
    bounceOffset*: array[3, float]    # Add bounce effect when stopping
    winningLines*: seq[array[3, tuple[col, row: int]]]  # Store winning line positions

const SYMBOLS = ["7", "BAR", "🍒", "🍋", "⭐", "💎", "🔔", "🍇", "🍊", "💰"]

proc easeOutCubic(t: float): float =
  let t2 = 1.0 - t
  return 1.0 - t2 * t2 * t2

proc newSlots*(pos: Vector3): Slots =
  result = Slots()
  result.position = pos
  result.reels = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
  result.targetReels = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
  result.spinProgress = [0.0, 0.0, 0.0]
  result.reelOffset = [0.0, 0.0, 0.0]
  result.state = Idle
  result.bet = 0
  result.timer = 0.0
  result.moneyAwarded = false
  result.moneyToAward = 0
  result.moneyAwardedSoFar = 0
  result.moneyTimer = 0.0
  result.leverAngle = 0.0
  result.screenShake = 0.0
  result.winGlow = 0.0
  result.anticipation = 0.0
  result.flashTimer = 0.0
  result.particleTimer = 0.0
  result.particles = @[]
  result.symbolRotation = [0.0, 0.0, 0.0]
  result.bounceOffset = [0.0, 0.0, 0.0]
  result.winningLines = @[]

proc drawSymbol3D(symbol: string, pos: Vector3, size: float, color: Color, rotation: float = 0.0) =
  pushMatrix()
  translatef(pos.x, pos.y, pos.z)
  rotatef(rotation * 360.0, 0, 0, 1)  # Rotate around Z axis
  translatef(-pos.x, -pos.y, -pos.z)
  
  case symbol:
  of "7":
    drawCube(Vector3(x: pos.x, y: pos.y + size * 0.3, z: pos.z), size * 0.6, size * 0.1, size * 0.1, color)
    drawCube(Vector3(x: pos.x + size * 0.2, y: pos.y, z: pos.z), size * 0.2, size * 0.6, size * 0.1, color)
  of "BAR":
    for i in 0..2:
      let yOff = (i.float - 1.0) * size * 0.25
      drawCube(Vector3(x: pos.x, y: pos.y + yOff, z: pos.z), size * 0.6, size * 0.15, size * 0.1, color)
  of "🍒":
    drawSphere(Vector3(x: pos.x - size * 0.15, y: pos.y, z: pos.z), size * 0.2, Red)
    drawSphere(Vector3(x: pos.x + size * 0.15, y: pos.y, z: pos.z), size * 0.2, Red)
  of "🍋":
    for i in -3..3:
      let offset = i.float * 0.08 * size
      let radius = size * 0.25 * (1.0 - abs(i.float) / 4.0)
      drawSphere(Vector3(x: pos.x + offset, y: pos.y, z: pos.z), radius, Yellow)
  of "⭐":
    drawSphere(pos, size * 0.2, Gold)
    for i in 0..4:
      let angle = i.float * PI * 0.4 - PI * 0.5
      let px = pos.x + cos(angle) * size * 0.3
      let py = pos.y + sin(angle) * size * 0.3
      drawSphere(Vector3(x: px, y: py, z: pos.z), size * 0.1, Gold)
  of "💎":
    # Draw diamond shape with multiple layers for sparkle effect
    let cyan = Color(r: 0, g: 255, b: 255, a: 255)
    let lightCyan = Color(r: 100, g: 255, b: 255, a: 255)
    
    # Bottom pyramid
    drawCube(Vector3(x: pos.x, y: pos.y - size * 0.15, z: pos.z), 
             size * 0.35, size * 0.2, size * 0.1, cyan)
    # Top pyramid
    drawCube(Vector3(x: pos.x, y: pos.y + size * 0.15, z: pos.z), 
             size * 0.35, size * 0.2, size * 0.1, lightCyan)
    # Center octahedron
    drawSphere(pos, size * 0.18, Skyblue)
    # Sparkle points
    for i in 0..3:
      let angle = i.float * PI * 0.5
      let px = pos.x + cos(angle) * size * 0.25
      let py = pos.y + sin(angle) * size * 0.25
      drawSphere(Vector3(x: px, y: py, z: pos.z), size * 0.05, White)
  of "🔔":
    # Draw bell shape
    let bellGold = Color(r: 255, g: 215, b: 0, a: 255)
    let darkGold = Color(r: 200, g: 170, b: 0, a: 255)
    
    # Bell body (wider at bottom)
    drawSphere(Vector3(x: pos.x, y: pos.y + size * 0.05, z: pos.z), size * 0.18, bellGold)
    drawCube(Vector3(x: pos.x, y: pos.y - size * 0.08, z: pos.z), 
             size * 0.35, size * 0.15, size * 0.1, bellGold)
    
    # Bell top/crown
    drawCube(Vector3(x: pos.x, y: pos.y + size * 0.25, z: pos.z), 
             size * 0.12, size * 0.08, size * 0.08, darkGold)
    
    # Bell clapper (small sphere at bottom)
    drawSphere(Vector3(x: pos.x, y: pos.y - size * 0.22, z: pos.z), size * 0.08, Gray)
    
    # Shine effect on bell
    drawSphere(Vector3(x: pos.x - size * 0.1, y: pos.y + size * 0.1, z: pos.z), 
               size * 0.05, Color(r: 255, g: 255, b: 200, a: 255))
  of "🍇":
    # Draw grape bunch
    let purple = Color(r: 138, g: 43, b: 226, a: 255)
    let darkPurple = Color(r: 100, g: 20, b: 150, a: 255)
    
    # Multiple rows of grapes
    for row in 0..2:
      let numGrapes = 3 - row
      for i in 0..<numGrapes:
        let xOffset = (i.float - (numGrapes.float - 1.0) * 0.5) * size * 0.15
        let yOffset = -row.float * size * 0.13
        drawSphere(Vector3(x: pos.x + xOffset, y: pos.y + yOffset, z: pos.z), 
                   size * 0.12, if row == 0: purple else: darkPurple)
    
    # Stem
    drawCube(Vector3(x: pos.x, y: pos.y + size * 0.22, z: pos.z), 
             size * 0.05, size * 0.12, size * 0.05, Green)
  of "🍊":
    # Draw orange
    let orange = Color(r: 255, g: 165, b: 0, a: 255)
    let darkOrange = Color(r: 255, g: 140, b: 0, a: 255)
    
    # Main orange body (slightly squashed sphere)
    for i in -2..2:
      let offset = i.float * 0.06 * size
      let radius = size * 0.22 * (1.0 - abs(i.float) / 3.0)
      let color = if i == 0: orange else: darkOrange
      drawSphere(Vector3(x: pos.x + offset, y: pos.y, z: pos.z), radius, color)
    
    # Small green stem/leaf on top
    drawSphere(Vector3(x: pos.x, y: pos.y + size * 0.25, z: pos.z), size * 0.06, Green)
  of "💰":
    # Draw money bag
    let bagBrown = Color(r: 139, g: 90, b: 43, a: 255)
    let lightBrown = Color(r: 160, g: 110, b: 60, a: 255)
    
    # Bag body (bottom part)
    drawSphere(Vector3(x: pos.x, y: pos.y - size * 0.08, z: pos.z), size * 0.25, bagBrown)
    
    # Bag top (tied part)
    drawCube(Vector3(x: pos.x, y: pos.y + size * 0.12, z: pos.z), 
             size * 0.18, size * 0.15, size * 0.1, lightBrown)
    
    # String/rope on top
    drawCube(Vector3(x: pos.x, y: pos.y + size * 0.22, z: pos.z), 
             size * 0.22, size * 0.04, size * 0.04, Color(r: 80, g: 60, b: 30, a: 255))
    
    # Dollar sign on bag
    drawCube(Vector3(x: pos.x, y: pos.y - size * 0.08, z: pos.z - 0.01), 
             size * 0.08, size * 0.2, size * 0.01, Gold)
    drawCube(Vector3(x: pos.x, y: pos.y - size * 0.15, z: pos.z - 0.01), 
             size * 0.12, size * 0.04, size * 0.01, Gold)
    drawCube(Vector3(x: pos.x, y: pos.y, z: pos.z - 0.01), 
             size * 0.12, size * 0.04, size * 0.01, Gold)
  else:
    drawCube(pos, size, size, size * 0.1, color)
  
  popMatrix()

proc draw3D*(slots: Slots) =
  pushMatrix()
  translatef(slots.position.x, slots.position.y, slots.position.z)
  rotatef(180, 0, 1, 0)
  translatef(-slots.position.x, -slots.position.y, -slots.position.z)

  var shakeOffset = Vector3(x: 0.0, y: 0.0, z: 0.0)
  if slots.screenShake > 0.0:
    shakeOffset.x = (rand(1.0) - 0.5) * slots.screenShake * 0.1
    shakeOffset.y = (rand(1.0) - 0.5) * slots.screenShake * 0.1
  let bodyPos = Vector3(
    x: slots.position.x + shakeOffset.x,
    y: slots.position.y + 1.0 + shakeOffset.y,
    z: slots.position.z + shakeOffset.z
  )
  # Larger body to accommodate 3 rows with better spacing
  drawCube(bodyPos, 1.8, 2.4, 0.5, DarkGray)

  if slots.winGlow > 0.0:
    let glowColor = Color(
      r: 255,
      g: uint8(215.0 * slots.winGlow),
      b: 0,
      a: uint8(255.0 * slots.winGlow)
    )
    drawCubeWires(bodyPos, 1.85, 2.45, 0.55, glowColor)

  drawCubeWires(bodyPos, 1.8, 2.4, 0.5, Gold)
  
  # Draw 3 columns x 3 rows with smaller, better-spaced boxes
  for col in 0..2:
    let bounceY = slots.bounceOffset[col]
    
    for row in 0..2:
      let reelPos = Vector3(
        x: slots.position.x - 0.5 + col.float * 0.5,  # Reduced spacing from 0.6 to 0.5
        y: bodyPos.y + 0.6 - row.float * 0.6 + slots.reelOffset[col] + shakeOffset.y + bounceY,  # Reduced from 0.7
        z: slots.position.z - 0.26
      )

      drawCube(reelPos, 0.42, 0.5, 0.02, Black)  # Reduced from 0.5, 0.6
      
      # Check if this position is part of a winning line
      var isWinningSymbol = false
      for line in slots.winningLines:
        for pos in line:
          if pos.col == col and pos.row == row:
            isWinningSymbol = true
            break
      
      let borderColor = if slots.state == Spinning:
        let spinGlow = sin(getTime() * 10.0) * 0.3 + 0.7
        Color(r: 255, g: 215, b: 0, a: uint8(255.0 * spinGlow))
      elif isWinningSymbol and slots.state == Result:
        # Highlight winning symbols
        let winGlow = (sin(getTime() * 8.0) + 1.0) * 0.5
        Color(r: 255, g: uint8(50 + 205 * winGlow), b: 0, a: 255)
      else:
        Yellow
      drawCubeWires(reelPos, 0.42, 0.5, 0.02, borderColor)  # Reduced from 0.5, 0.6
      
      let offset = slots.reelOffset[col]
      
      if slots.spinProgress[col] < 1.0:
        # During spinning, show scrolling symbols
        let symbolIndex = (slots.reels[col][row] + int(offset * 3.0)) mod SYMBOLS.len
        let current = SYMBOLS[symbolIndex]
        let spinRotation = slots.spinProgress[col] * 2.0
        drawSymbol3D(current, Vector3(x: reelPos.x, y: reelPos.y, z: reelPos.z - 0.02), 
                     0.23, White, spinRotation)  # Reduced from 0.28 to 0.23
      else:
        let final = SYMBOLS[slots.reels[col][row]]
        let idleRotation = sin(getTime() * 1.5 + col.float + row.float) * 0.02
        let symbolColor = if isWinningSymbol: Gold else: White
        drawSymbol3D(final, Vector3(x: reelPos.x, y: reelPos.y, z: reelPos.z - 0.02), 
                     0.23, symbolColor, slots.symbolRotation[col] + idleRotation)  # Reduced from 0.28 to 0.23
  let baseY = sin(slots.anticipation * PI * 4.0) * 0.02
  drawCube(Vector3(x: slots.position.x, y: slots.position.y + baseY, z: slots.position.z), 2.0, 0.2, 0.7, Maroon)  # Reduced width from 2.2 to 2.0
  let handleBase = Vector3(x: slots.position.x + 1.1, y: bodyPos.y - 0.3, z: slots.position.z)
  let handleTipY = handleBase.y + cos(slots.leverAngle) * 0.6
  let handleTipX = handleBase.x + sin(slots.leverAngle) * 0.2
  drawCylinder(handleBase, 0.05, 0.05, 0.6, 8, Red)
  drawSphere(Vector3(x: handleTipX, y: handleTipY, z: handleBase.z), 0.15, Red)
  for particle in slots.particles:
    if particle.life > 0.0:
      let size = particle.life * 0.1
      let particlePos = Vector3(
        x: slots.position.x + particle.x,
        y: slots.position.y + 1.0 + particle.y,
        z: slots.position.z - 0.3
      )
      drawSphere(particlePos, size, Gold)
  popMatrix()

proc update*(slots: Slots, deltaTime: float) =
  if slots.state == LeverPull:
    slots.leverAngle += deltaTime * 8.0
    if slots.leverAngle >= PI * 0.4:
      slots.state = Spinning
      slots.leverAngle = PI * 0.4
      slots.anticipation = 0.0
  elif slots.leverAngle > 0.0:
    slots.leverAngle -= deltaTime * 6.0
    if slots.leverAngle < 0.0:
      slots.leverAngle = 0.0
  
  if slots.state == Idle and slots.bet > 0:
    slots.anticipation += deltaTime * 0.5
    if slots.anticipation > 1.0:
      slots.anticipation = 1.0
  else:
    slots.anticipation = 0.0
  
  if slots.state == Spinning:
    var allStopped = true
    for i in 0..2:
      # Update bounce effect
      if slots.bounceOffset[i] != 0.0:
        slots.bounceOffset[i] -= deltaTime * 0.4
        if slots.bounceOffset[i] < 0.0:
          slots.bounceOffset[i] = 0.0
      
      if slots.spinProgress[i] < 1.0:
        let baseSpeed = 1.2 + i.float * 0.4
        slots.spinProgress[i] += deltaTime * baseSpeed
        
        # Update symbol rotation during spin (keep between 0 and 1)
        slots.symbolRotation[i] += deltaTime * 5.0
        if slots.symbolRotation[i] > 1.0:
          slots.symbolRotation[i] = slots.symbolRotation[i] mod 1.0
        
        if slots.spinProgress[i] < 0.7:
          slots.reelOffset[i] += deltaTime * 9.0  # Scroll speed
          if slots.reelOffset[i] >= 1.0:
            slots.reelOffset[i] = 0.0
            # Cycle all 3 rows
            for row in 0..2:
              slots.reels[i][row] = (slots.reels[i][row] + 1) mod SYMBOLS.len
        else:
          let easedProgress = 0.7 + easeOutCubic((slots.spinProgress[i] - 0.7) / 0.3) * 0.3
          slots.spinProgress[i] = min(easedProgress, 1.0)
          let slowdownFactor = (1.0 - (slots.spinProgress[i] - 0.7) / 0.3)
          slots.reelOffset[i] += deltaTime * 8.0 * slowdownFactor
          if slots.reelOffset[i] >= 1.0:
            slots.reelOffset[i] = 0.0
            for row in 0..2:
              slots.reels[i][row] = (slots.reels[i][row] + 1) mod SYMBOLS.len

        if slots.spinProgress[i] >= 1.0:
          slots.spinProgress[i] = 1.0
          slots.reels[i] = slots.targetReels[i]
          slots.reelOffset[i] = 0.0
          # Add bounce effect when reel stops
          slots.bounceOffset[i] = 0.15
          slots.symbolRotation[i] = 0.0  # Reset rotation
        allStopped = false
      else:
        slots.reelOffset[i] = 0.0

    if allStopped:
      slots.state = Result
      slots.timer = 0.0
      slots.winningLines = @[]
      
      # Check all possible winning lines (8 lines total)
      var hasWin = false
      
      # Horizontal lines (3 lines)
      for row in 0..2:
        if slots.reels[0][row] == slots.reels[1][row] and 
           slots.reels[1][row] == slots.reels[2][row]:
          hasWin = true
          slots.winningLines.add([
            (col: 0, row: row),
            (col: 1, row: row),
            (col: 2, row: row)
          ])
      
      # Vertical lines (3 lines)
      for col in 0..2:
        if slots.reels[col][0] == slots.reels[col][1] and 
           slots.reels[col][1] == slots.reels[col][2]:
          hasWin = true
          slots.winningLines.add([
            (col: col, row: 0),
            (col: col, row: 1),
            (col: col, row: 2)
          ])
      
      # Diagonal lines (2 lines)
      if slots.reels[0][0] == slots.reels[1][1] and 
         slots.reels[1][1] == slots.reels[2][2]:
        hasWin = true
        slots.winningLines.add([
          (col: 0, row: 0),
          (col: 1, row: 1),
          (col: 2, row: 2)
        ])
      
      if slots.reels[0][2] == slots.reels[1][1] and 
         slots.reels[1][1] == slots.reels[2][0]:
        hasWin = true
        slots.winningLines.add([
          (col: 0, row: 2),
          (col: 1, row: 1),
          (col: 2, row: 0)
        ])
      
      if hasWin:
        slots.screenShake = 1.0
        slots.flashTimer = 0.5
        # More particles for winning
        for _ in 0..39:
          slots.particles.add((
            x: rand(1.0) - 0.5,
            y: rand(1.0),
            life: rand(1.0) + 1.0
          ))

  if slots.screenShake > 0.0:
    slots.screenShake -= deltaTime * 2.0
    if slots.screenShake < 0.0:
      slots.screenShake = 0.0

  if slots.state == Result and slots.moneyToAward > 0:
    slots.winGlow = (sin(getTime() * 6.0) + 1.0) * 0.5
  else:
    slots.winGlow = 0.0

  if slots.flashTimer > 0.0:
    slots.flashTimer -= deltaTime

  var newParticles: seq[tuple[x, y, life: float]] = @[]
  for particle in slots.particles:
    var p = particle
    p.life -= deltaTime
    p.y += deltaTime * 2.0
    if p.life > 0.0:
      newParticles.add(p)
  slots.particles = newParticles

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
      messages.add("Win: Line = 20x bet")
      messages.add("8 lines: 3 rows, 3 cols, 2 diagonals")
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
      elif isKeyPressed(Escape):
        return true
    else:
      messages.add("Bet: " & formatMoney(slots.bet))
      messages.add("")
      messages.add("[SPACE] Pull lever!")
      messages.add("[ESC] Cancel bet")

      if isKeyPressed(Space):
        slots.state = LeverPull
        slots.leverAngle = 0.0
        slots.spinProgress = [0.0, 0.0, 0.0]
        slots.reelOffset = [0.0, 0.0, 0.0]
        slots.symbolRotation = [0.0, 0.0, 0.0]
        slots.bounceOffset = [0.0, 0.0, 0.0]
        slots.moneyAwarded = false
        slots.moneyToAward = 0
        slots.moneyAwardedSoFar = 0
        slots.moneyTimer = 0.0
        slots.particles = @[]
        slots.winningLines = @[]
        # Generate random target for each position in 3x3 grid
        for col in 0..2:
          for row in 0..2:
            slots.targetReels[col][row] = rand(SYMBOLS.len - 1)

    drawMinigameUI("SLOTS", player, messages)

    if isKeyPressed(Escape):
      if slots.bet > 0:
        player.addMoney(slots.bet)
      slots.bet = 0
      return true

  elif slots.state == LeverPull or slots.state == Spinning:
    slots.update(getFrameTime())
    var messages: seq[string] = @[]

    if slots.state == LeverPull:
      messages.add("=== GET READY! ===")
    else:
      messages.add("=== SPINNING ===")
    
    drawMinigameUI("SLOTS", player, messages)
  
  elif slots.state == Result:
    slots.update(getFrameTime())
    
    var messages: seq[string] = @[]
    
    if slots.flashTimer > 0.0 and (int(slots.flashTimer * 10.0) mod 2 == 0):
      messages.add("=== ⭐ WINNER!!! ⭐ ===")
    else:
      messages.add("=== RESULT ===")
    
    messages.add("")
    
    if not slots.moneyAwarded:
      let numLines = slots.winningLines.len
      
      if numLines > 0:
        # Multiple of 10x per line
        slots.moneyToAward = slots.bet * numLines * 10
        if numLines == 1:
          messages.add("⭐ 1 WINNING LINE! ⭐")
        else:
          messages.add("⭐⭐ " & $numLines & " WINNING LINES! ⭐⭐")
        messages.add("Won: " & formatMoney(slots.moneyToAward))
      else:
        slots.moneyToAward = 0
        messages.add("✗ NO WINNING LINES")
        messages.add("Lost: " & formatMoney(slots.bet))
      slots.moneyAwarded = true
    else:
      slots.moneyTimer += getFrameTime()
      
      if slots.moneyTimer >= 0.05 and slots.moneyAwardedSoFar < slots.moneyToAward:
        slots.moneyTimer = 0.0
        
        var increment: int
        if slots.moneyToAward < 100:
          increment = 5
        elif slots.moneyToAward < 500:
          increment = 10
        elif slots.moneyToAward < 1000:
          increment = 25
        else:
          increment = 50
        
        increment = min(increment, slots.moneyToAward - slots.moneyAwardedSoFar)
        player.addMoney(increment)
        slots.moneyAwardedSoFar += increment
      
      let numLines = slots.winningLines.len
      
      if numLines > 0:
        if numLines == 1:
          messages.add("⭐ 1 WINNING LINE! ⭐")
        else:
          messages.add("⭐⭐ " & $numLines & " WINNING LINES! ⭐⭐")
        messages.add("Won: " & formatMoney(slots.moneyToAward))
      else:
        messages.add("✗ NO WINNING LINES")
        messages.add("Lost: " & formatMoney(slots.bet))
    
    messages.add("")
    
    if slots.moneyAwardedSoFar >= slots.moneyToAward:
      messages.add("Press any key to continue...")
    else:
      messages.add("Awarding winnings...")
    
    drawMinigameUI("SLOTS", player, messages)
    
    if slots.moneyAwardedSoFar >= slots.moneyToAward and getKeyPressed() != KeyboardKey.Null:
      slots.bet = 0
      slots.state = Idle
      slots.screenShake = 0.0
      slots.winGlow = 0.0
      slots.particles = @[]
      return false
  
  return false
