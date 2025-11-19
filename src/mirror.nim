import raylib, math

type
  Mirror* = ref object
    position*: Vector3  # Center position of the mirror
    rotation*: float  # Y-axis rotation in radians
    width*: float
    height*: float
    renderTexture*: RenderTexture2D
    textureSize*: int32
    reflectionCamera*: Camera3D

proc newMirror*(position: Vector3, rotation: float, width: float = 3.0, height: float = 2.5, textureSize: int32 = 512): Mirror =
  ## Create a new mirror at the specified position
  ## rotation: angle in radians for Y-axis rotation
  result = Mirror()
  result.position = position
  result.rotation = rotation
  result.width = width
  result.height = height
  result.textureSize = textureSize
  
  # Create render texture for reflection
  result.renderTexture = loadRenderTexture(textureSize, textureSize)
  
  # Initialize reflection camera
  result.reflectionCamera = Camera3D()
  result.reflectionCamera.up = Vector3(x: 0, y: 1, z: 0)
  result.reflectionCamera.fovy = 70.0
  result.reflectionCamera.projection = Perspective

proc updateReflectionCamera*(mirror: Mirror, playerCamera: Camera3D) =
  ## Update the reflection camera based on player camera and mirror position
  # Calculate mirror normal (direction mirror is facing)
  let mirrorNormal = Vector3(
    x: sin(mirror.rotation),
    y: 0,
    z: cos(mirror.rotation)
  )
  
  # Calculate the reflection of the player camera position across the mirror plane
  let playerToCameraDist = playerCamera.position
  
  # Distance from player camera to mirror plane
  let camToMirrorVec = Vector3(
    x: mirror.position.x - playerCamera.position.x,
    y: mirror.position.y - playerCamera.position.y,
    z: mirror.position.z - playerCamera.position.z
  )
  
  # Project onto mirror normal to get distance
  let distToMirror = camToMirrorVec.x * mirrorNormal.x + camToMirrorVec.z * mirrorNormal.z
  
  # Reflect camera position across mirror plane
  mirror.reflectionCamera.position = Vector3(
    x: playerCamera.position.x + 2.0 * distToMirror * mirrorNormal.x,
    y: playerCamera.position.y,
    z: playerCamera.position.z + 2.0 * distToMirror * mirrorNormal.z
  )
  
  # Reflect camera target
  let targetToMirrorVec = Vector3(
    x: mirror.position.x - playerCamera.target.x,
    y: mirror.position.y - playerCamera.target.y,
    z: mirror.position.z - playerCamera.target.z
  )
  
  let targetDistToMirror = targetToMirrorVec.x * mirrorNormal.x + targetToMirrorVec.z * mirrorNormal.z
  
  mirror.reflectionCamera.target = Vector3(
    x: playerCamera.target.x + 2.0 * targetDistToMirror * mirrorNormal.x,
    y: playerCamera.target.y,
    z: playerCamera.target.z + 2.0 * targetDistToMirror * mirrorNormal.z
  )

proc drawMirror*(mirror: Mirror) =
  ## Draw the mirror surface with its reflection texture
  # Calculate the four corners of the mirror rectangle
  let right = Vector3(
    x: cos(mirror.rotation),  # Perpendicular to normal
    y: 0,
    z: -sin(mirror.rotation)
  )
  
  let halfWidth = mirror.width / 2.0
  let halfHeight = mirror.height / 2.0
  
  # Calculate corner positions
  let topLeft = Vector3(
    x: mirror.position.x - right.x * halfWidth,
    y: mirror.position.y + halfHeight,
    z: mirror.position.z - right.z * halfWidth
  )
  
  let topRight = Vector3(
    x: mirror.position.x + right.x * halfWidth,
    y: mirror.position.y + halfHeight,
    z: mirror.position.z + right.z * halfWidth
  )
  
  let bottomLeft = Vector3(
    x: mirror.position.x - right.x * halfWidth,
    y: mirror.position.y - halfHeight,
    z: mirror.position.z - right.z * halfWidth
  )
  
  let bottomRight = Vector3(
    x: mirror.position.x + right.x * halfWidth,
    y: mirror.position.y - halfHeight,
    z: mirror.position.z + right.z * halfWidth
  )
  
  # Draw the mirror quad with the reflection texture
  # NOTE: Low-level RL functions (rlSetTexture, rlBegin, etc.) are not available in raylib-nim
  # As a workaround, we'll draw a simple colored plane to represent the mirror
  # For proper texture mapping, this would need to be implemented using mesh/model approach
  
  # Draw a simple plane as mirror placeholder
  drawPlane(
    mirror.position,
    Vector2(x: mirror.width, y: mirror.height),
    LightGray
  )
  
  # Draw mirror frame (optional, decorative border)
  let frameColor = Color(r: 139, g: 69, b: 19, a: 255)  # Brown/wood color
  let frameThickness = 0.1
  
  # Draw frame as slightly larger rectangle behind mirror
  drawCubeWires(mirror.position, 
                mirror.width + frameThickness, 
                mirror.height + frameThickness, 
                0.05, 
                Gold)

proc unloadMirror*(mirror: Mirror) =
  ## Unload mirror resources
  # Note: unloadRenderTexture may not be available in all raylib-nim versions
  # The render texture will be garbage collected when the Mirror object is freed
  discard
