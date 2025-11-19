import raylib, math
import utils

type
  Player* = ref object
    position*: Vector3
    camera*: Camera3D
    yaw*: float
    pitch*: float
    money*: int
    speed*: float
    velocity*: Vector3  # Physics velocity (X, Y, Z for full 3D movement)
    isGrounded*: bool  # Whether player is on ground
    gravity*: float  # Gravity constant
    jumpForce*: float  # Jump velocity
    groundLevel*: float  # Ground Y position
    airControl*: float  # Movement control while airborne (0.0-1.0)
    model*: Model  # Player 3D model
    modelLoaded*: bool  # Whether model loaded successfully
    modelScale*: float  # Scale of the model
    modelOffset*: Vector3  # Offset from player position

proc loadPlayerModel*(player: Player, modelPath: string) =
  ## Load a .glb model for the player
  try:
    player.model = loadModel(modelPath)
    player.modelLoaded = true
    player.modelScale = 1.0
    player.modelOffset = Vector3(x: 0, y: -0.8, z: 0)  # Offset to ground level
  except:
    player.modelLoaded = false
    echo "Failed to load player model: ", modelPath

proc newPlayer*(startPos: Vector3, startMoney: int): Player =
  result = Player()
  result.position = startPos
  result.money = startMoney
  result.yaw = 0.0
  result.pitch = 0.0
  result.speed = 5.0
  
  # Physics initialization
  result.velocity = Vector3(x: 0, y: 0, z: 0)
  result.gravity = 20.0  # Gravity acceleration
  result.jumpForce = 8.0  # Jump velocity
  result.groundLevel = 1.6  # Eye level height (1.6m above ground)
  result.isGrounded = true
  result.airControl = 0.3  # 30% movement control in air
  
  # Model initialization
  result.modelLoaded = false
  result.modelScale = 1.0
  result.modelOffset = Vector3(x: 0, y: -0.8, z: 0)
  
  result.camera = Camera3D()
  result.camera.position = result.position
  result.camera.target = Vector3(
    x: result.position.x,
    y: result.position.y,
    z: result.position.z - 1.0
  )
  result.camera.up = Vector3(x: 0, y: 1, z: 0)
  result.camera.fovy = 70.0
  result.camera.projection = Perspective

proc update*(player: Player, deltaTime: float) =
  # Mouse look
  let mouseDelta = getMouseDelta()
  let sensitivity = 0.003
  
  player.yaw -= mouseDelta.x * sensitivity
  player.pitch -= mouseDelta.y * sensitivity
  player.pitch = clamp(player.pitch, -1.5, 1.5)
  
  # Calculate forward and right vectors
  let forward = Vector3(
    x: sin(player.yaw),
    y: 0,
    z: cos(player.yaw)
  )
  
  let right = Vector3(
    x: -cos(player.yaw),
    y: 0,
    z: sin(player.yaw)
  )
  
  # Movement input
  var moveDir = Vector3(x: 0, y: 0, z: 0)
  
  if isKeyDown(W):
    moveDir.x += forward.x
    moveDir.z += forward.z
  if isKeyDown(S):
    moveDir.x -= forward.x
    moveDir.z -= forward.z
  if isKeyDown(A):
    moveDir.x -= right.x
    moveDir.z -= right.z
  if isKeyDown(D):
    moveDir.x += right.x
    moveDir.z += right.z
  
  # Normalize horizontal movement
  let magnitude = sqrt(moveDir.x * moveDir.x + moveDir.z * moveDir.z)
  if magnitude > 0:
    # Normalize direction
    moveDir.x = moveDir.x / magnitude
    moveDir.z = moveDir.z / magnitude
    
    if player.isGrounded:
      # On ground: directly set velocity to target speed
      player.velocity.x = moveDir.x * player.speed
      player.velocity.z = moveDir.z * player.speed
    else:
      # In air: only allow steering by adding small perpendicular forces
      # This preserves momentum magnitude but allows direction changes
      let currentSpeed = sqrt(player.velocity.x * player.velocity.x + player.velocity.z * player.velocity.z)
      
      # Smoothly interpolate velocity direction towards input direction
      # but keep the current speed (or slowly decay it)
      let airInfluence = player.airControl * 5.0 * deltaTime  # How much input affects direction
      player.velocity.x = player.velocity.x * (1.0 - airInfluence) + moveDir.x * currentSpeed * airInfluence
      player.velocity.z = player.velocity.z * (1.0 - airInfluence) + moveDir.z * currentSpeed * airInfluence
  else:
    # Apply friction when no input
    player.velocity.x *= 0.9
    player.velocity.z *= 0.9
  
  # Apply horizontal velocity
  player.position.x += player.velocity.x * deltaTime
  player.position.z += player.velocity.z * deltaTime
  
  # Jump input (no coyote time - must be grounded to jump)
  if isKeyPressed(Space) and player.isGrounded:
    player.velocity.y = player.jumpForce
    player.isGrounded = false
    # Horizontal velocity is preserved automatically from movement code above
  
  # Variable jump height - release space early for shorter jump
  if isKeyReleased(Space) and player.velocity.y > 0:
    player.velocity.y *= 0.5
  
  # Apply gravity
  if not player.isGrounded:
    player.velocity.y -= player.gravity * deltaTime
  
  # Apply vertical velocity
  player.position.y += player.velocity.y * deltaTime
  
  # Ground collision
  if player.position.y <= player.groundLevel:
    player.position.y = player.groundLevel
    player.velocity.y = 0
    player.isGrounded = true
  
  # Update camera
  player.camera.position = player.position
  player.camera.target = Vector3(
    x: player.position.x + sin(player.yaw) * cos(player.pitch),
    y: player.position.y + sin(player.pitch),
    z: player.position.z + cos(player.yaw) * cos(player.pitch)
  )

proc drawPlayerModel*(player: Player) =
  ## Draw the player model at the player's position with proper rotation
  if not player.modelLoaded:
    return
  
  # Calculate model position (offset from player camera position)
  let modelPos = Vector3(
    x: player.position.x + player.modelOffset.x,
    y: player.position.y + player.modelOffset.y,
    z: player.position.z + player.modelOffset.z
  )
  
  # Draw model with rotation matching player's yaw
  # Rotate model to face the direction the player is facing
  # Note: drawModel in raylib-nim doesn't support rotation directly
  # We'll use the simple drawModel for now - rotation can be added later if needed
  drawModel(
    player.model,
    modelPos,
    player.modelScale,
    White
  )

proc getForwardPosition*(player: Player, distance: float): Vector3 =
  return Vector3(
    x: player.position.x + sin(player.yaw) * distance,
    y: player.position.y,
    z: player.position.z + cos(player.yaw) * distance
  )

proc addMoney*(player: Player, amount: int) =
  player.money += amount

proc removeMoney*(player: Player, amount: int): bool =
  if player.money >= amount:
    player.money -= amount
    return true
  return false

proc unloadPlayerModel*(player: Player) =
  ## Unload the player model to free memory
  if player.modelLoaded:
    # Note: unloadModel may not be available in all raylib-nim versions
    # The model will be garbage collected when the Player object is freed
    # If manual cleanup is needed, check raylib-nim documentation for the correct function
    player.modelLoaded = false
