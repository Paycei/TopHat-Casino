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

proc newPlayer*(startPos: Vector3, startMoney: int): Player =
  result = Player()
  result.position = startPos
  result.money = startMoney
  result.yaw = 0.0
  result.pitch = 0.0
  result.speed = 5.0
  
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
  
  # Movement
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
  
  # Normalize and apply speed
  let magnitude = sqrt(moveDir.x * moveDir.x + moveDir.z * moveDir.z)
  if magnitude > 0:
    moveDir.x = (moveDir.x / magnitude) * player.speed * deltaTime
    moveDir.z = (moveDir.z / magnitude) * player.speed * deltaTime
    
    player.position.x += moveDir.x
    player.position.z += moveDir.z
  
  # Update camera
  player.camera.position = player.position
  player.camera.target = Vector3(
    x: player.position.x + sin(player.yaw) * cos(player.pitch),
    y: player.position.y + sin(player.pitch),
    z: player.position.z + cos(player.yaw) * cos(player.pitch)
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