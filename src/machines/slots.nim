import raylib, math, random
import ../utils, ../player, ../ui

type
  SlotState = enum
    Idle, LeverPull, Spinning, Result
  
  Slots* = ref object
    position*: Vector3
    reels*: array[3, int]
    targetReels*: array[3, int]
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

const SYMBOLS = ["7", "BAR", "🍒", "🍋", "⭐"]

proc easeOutBounce(t: float): float =
  if t < (1.0 / 2.75):
    return 7.5625 * t * t
  elif t < (2.0 / 2.75):
    let t2 = t - (1.5 / 2.75)
    return 7.5625 * t2 * t2 + 0.75
  elif t < (2.5 / 2.75):
    let t2 = t - (2.25 / 2.75)
    return 7.5625 * t2 * t2 + 0.9375
  else:
    let t2 = t - (2.625 / 2.75)
    return 7.5625 * t2 * t2 + 0.984375

proc easeOutCubic(t: float): float =
  let t2 = 1.0 - t
  return 1.0 - t2 * t2 * t2

proc newSlots*(pos: Vector3): Slots =
  result = Slots()
  result.position = pos
  result.reels = [0, 0, 0]
  result.targetReels = [0, 0, 0]
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

proc drawSymbol3D(symbol: string, pos: Vector3, size: float, color: Color) =
  # Draw 3D symbol representation
  case symbol:
  of "7":
    # Draw 7 as cubes forming the shape
    drawCube(Vector3(x: pos.x, y: pos.y + size * 0.3, z: pos.z), size * 0.6, size * 0.1, size * 0.1, color)
    drawCube(Vector3(x: pos.x + size * 0.2, y: pos.y, z: pos.z), size * 0.2, size * 0.6, size * 0.1, color)
  of "BAR":
    # Three horizontal bars
    for i in 0..2:
      let yOff = (i.float - 1.0) * size * 0.25
      drawCube(Vector3(x: pos.x, y: pos.y + yOff, z: pos.z), size * 0.6, size * 0.15, size * 0.1, color)
  of "🍒":
    # Cherry as two spheres
    drawSphere(Vector3(x: pos.x - size * 0.15, y: pos.y, z: pos.z), size * 0.2, Red)
    drawSphere(Vector3(x: pos.x + size * 0.15, y: pos.y, z: pos.z), size * 0.2, Red)
  of "🍋":
    # Lemon as ellipsoid (stretched sphere)
    for i in -3..3:
      let offset = i.float * 0.08 * size
      let radius = size * 0.25 * (1.0 - abs(i.float) / 4.0)
      drawSphere(Vector3(x: pos.x + offset, y: pos.y, z: pos.z), radius, Yellow)
  of "⭐":
    # Star as central sphere with points
    drawSphere(pos, size * 0.2, Gold)
    for i in 0..4:
      let angle = i.float * PI * 0.4 - PI * 0.5
      let px = pos.x + cos(angle) * size * 0.3
      let py = pos.y + sin(angle) * size * 0.3
      drawSphere(Vector3(x: px, y: py, z: pos.z), size * 0.1, Gold)
  else:
    drawCube(pos, size, size, size * 0.1, color)

proc draw3D*(slots: Slots) =
  var shakeOffset = Vector3(x: 0.0, y: 0.0, z: 0.0)
  if slots.screenShake > 0.0:
    shakeOffset.x = (rand(1.0) - 0.5) * slots.screenShake * 0.1
    shakeOffset.y = (rand(1.0) - 0.5) * slots.screenShake * 0.1
  
  let bodyPos = Vector3(
    x: slots.position.x + shakeOffset.x,
    y: slots.position.y + 1.0 + shakeOffset.y,
    z: slots.position.z + shakeOffset.z
  )
  drawCube(bodyPos, 2.0, 2.0, 0.5, DarkGray)
  
  if slots.winGlow > 0.0:
    let glowColor = Color(
      r: 255,
      g: uint8(215.0 * slots.winGlow),
      a: uint8(255.0 * slots.winGlow)
    )
    drawCubeWires(bodyPos, 2.05, 2.05, 0.55, glowColor)
  
  drawCubeWires(bodyPos, 2.0, 2.0, 0.5, Gold)
  
  # Screen reels with 3D symbols
  for i in 0..2:
    let reelPos = Vector3(
      x: bodyPos.x - 0.6 + i.float * 0.6,
      y: bodyPos.y + 0.3 + slots.reelOffset[i] + shakeOffset.y,
      z: bodyPos.z - 0.26
    )
    
    # Dark background
    drawCube(reelPos, 0.5, 0.8, 0.02, Black)
    
    if slots.state == Spinning:
      let spinGlow = sin(getTime() * 10.0) * 0.3 + 0.7
      let spinColor = Color(r: 255, g: 215, b: 0, a: uint8(255.0 * spinGlow))
      drawCubeWires(reelPos, 0.52, 0.82, 0.03, spinColor)
    else:
      drawCubeWires(reelPos, 0.5, 0.8, 0.02, Yellow)
    
    # Draw symbol in 3D
    let symbolPos = Vector3(
      x: reelPos.x,
      y: reelPos.y,
      z: reelPos.z - 0.02
    )
    
    if slots.spinProgress[i] < 1.0:
      # Blur during spin - show multiple symbols
      for j in 0..2:
        let blurIdx = (slots.reels[i] + j) mod SYMBOLS.len
        let blurY = symbolPos.y + (j.float - 1.0) * 0.25
        let alpha = 100 + int((1.0 - slots.spinProgress[i]) * 100.0)
        drawSymbol3D(SYMBOLS[blurIdx], Vector3(x: symbolPos.x, y: blurY, z: symbolPos.z), 0.3, 
                     Color(r: 255, g: 255, b: 255, a: uint8(alpha)))
    else:
      # Show final symbol
      drawSymbol3D(SYMBOLS[slots.reels[i]], symbolPos, 0.35, White)
  
  # Base
  let baseY = slots.position.y + sin(slots.anticipation * PI * 4.0) * 0.02
  let basePos = Vector3(x: slots.position.x, y: baseY, z: slots.position.z)
  drawCube(basePos, 2.2, 0.2, 0.7, Maroon)
  
  # Animated handle
  let handleBase = Vector3(
    x: bodyPos.x + 1.1,
    y: bodyPos.y - 0.3,
    z: bodyPos.z
  )
  
  let handleTipY = handleBase.y + cos(slots.leverAngle) * 0.6
  let handleTipX = handleBase.x + sin(slots.leverAngle) * 0.2
  
  drawCylinder(handleBase, 0.05, 0.05, 0.6, 8, Red)
  drawSphere(Vector3(x: handleTipX, y: handleTipY, z: handleBase.z), 0.15, Red)
  
  # Win particles
  for particle in slots.particles:
    if particle.life > 0.0:
      let size = particle.life * 0.1
      let particlePos = Vector3(
        x: bodyPos.x + particle.x,
        y: bodyPos.y + particle.y,
        z: bodyPos.z - 0.3
      )
      drawSphere(particlePos, size, Gold)

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
      if slots.spinProgress[i] < 1.0:
        let baseSpeed = 1.2 + i.float * 0.4
        slots.spinProgress[i] += deltaTime * baseSpeed
        
        if slots.spinProgress[i] >= 0.7:
          let easedProgress = 0.7 + easeOutCubic((slots.spinProgress[i] - 0.7) / 0.3) * 0.3
          slots.spinProgress[i] = min(easedProgress, 1.0)
        
        if slots.spinProgress[i] >= 1.0:
          slots.spinProgress[i] = 1.0
          slots.reels[i] = slots.targetReels[i]
          slots.reelOffset[i] = -0.2
        allStopped = false
      elif slots.reelOffset[i] != 0.0:
        slots.reelOffset[i] += deltaTime * 1.5
        if slots.reelOffset[i] > 0.0:
          slots.reelOffset[i] = 0.0
    
    if allStopped and slots.reelOffset[0] == 0.0 and slots.reelOffset[1] == 0.0 and slots.reelOffset[2] == 0.0:
      slots.state = Result
      slots.timer = 0.0
      
      let r0 = slots.reels[0]
      let r1 = slots.reels[1]
      let r2 = slots.reels[2]
      if r0 == r1 and r1 == r2:
        slots.screenShake = 1.0
        slots.flashTimer = 0.5
        for _ in 0..19:
          slots.particles.add((
            x: rand(1.0) - 0.5,
            y: rand(1.0),
            life: rand(1.0) + 0.5
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
      messages.add("Win: 3 same = 10x, 2 same = 2x")
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
        slots.moneyAwarded = false
        slots.moneyToAward = 0
        slots.moneyAwardedSoFar = 0
        slots.moneyTimer = 0.0
        slots.particles = @[]
        for i in 0..2:
          slots.targetReels[i] = rand(SYMBOLS.len - 1)
    
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
      messages.add("=== ⭐ JACKPOT!!! ⭐ ===")
    else:
      messages.add("=== RESULT ===")
    
    messages.add("")
    
    if not slots.moneyAwarded:
      let r0 = slots.reels[0]
      let r1 = slots.reels[1]
      let r2 = slots.reels[2]
      
      if r0 == r1 and r1 == r2:
        slots.moneyToAward = slots.bet * 10
        messages.add("⭐ JACKPOT! THREE OF A KIND! ⭐")
        messages.add("Won: " & formatMoney(slots.moneyToAward))
      elif r0 == r1 or r1 == r2 or r0 == r2:
        slots.moneyToAward = slots.bet * 2
        messages.add("✓ WIN! TWO OF A KIND!")
        messages.add("Won: " & formatMoney(slots.moneyToAward))
      else:
        slots.moneyToAward = 0
        messages.add("✗ NO MATCH")
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
      
      let r0 = slots.reels[0]
      let r1 = slots.reels[1]
      let r2 = slots.reels[2]
      
      if r0 == r1 and r1 == r2:
        messages.add("⭐ JACKPOT! THREE OF A KIND! ⭐")
        messages.add("Won: " & formatMoney(slots.moneyToAward))
      elif r0 == r1 or r1 == r2 or r0 == r2:
        messages.add("✓ WIN! TWO OF A KIND!")
        messages.add("Won: " & formatMoney(slots.moneyToAward))
      else:
        messages.add("✗ NO MATCH")
        messages.add("Lost: " & formatMoney(slots.bet))
    
    messages.add("")
    
    if slots.moneyAwardedSoFar >= slots.moneyToAward:
      messages.add("Press any key to continue...")
    else:
      messages.add("Awarding winnings...")
    
    drawMinigameUI("SLOTS", player, messages)
    
    if slots.moneyAwardedSoFar >= slots.moneyToAward and (isKeyPressed(Space) or isKeyPressed(Enter) or isKeyPressed(Escape)):
      slots.bet = 0
      slots.state = Idle
      slots.screenShake = 0.0
      slots.winGlow = 0.0
      slots.particles = @[]
      return true
  
  return false
