import raylib
import player, casino, ui, utils
import machines/roulette, machines/slots, machines/blackjack

type
  GameState* = enum
    MainMenu, Playing, InMachine, Paused
  
  Game* = ref object
    state*: GameState
    player*: Player
    casino*: Casino
    activeMachine*: int  # -1 for none, 0 = roulette, 1 = slots, 2 = blackjack
    interactionDistance*: float
    cameraTransition*: float  # 0.0 = playing, 1.0 = in machine
    targetCameraPos*: Vector3
    targetCameraTarget*: Vector3
    originalCameraPos*: Vector3
    originalCameraTarget*: Vector3
    exitingMachine*: bool  # Flag to prevent immediate input after exiting machine
    exitInputCooldown*: float
    pendingExit*: bool

proc newGame*(): Game =
  result = Game()
  result.state = MainMenu
  result.player = newPlayer(Vector3(x: 0, y: 1.6, z: 8), 500)
  result.casino = newCasino()
  result.activeMachine = -1
  result.interactionDistance = 3.0
  result.cameraTransition = 0.0
  result.targetCameraPos = Vector3(x: 0, y: 0, z: 0)
  result.targetCameraTarget = Vector3(x: 0, y: 0, z: 0)
  result.originalCameraPos = Vector3(x: 0, y: 0, z: 0)
  result.originalCameraTarget = Vector3(x: 0, y: 0, z: 0)
  result.exitingMachine = false
  result.exitInputCooldown = 0.0
  result.pendingExit = false


proc update*(game: Game) =
  let deltaTime = getFrameTime()
  if game.pendingExit:
    game.state = Playing
    game.activeMachine = -1
    game.pendingExit = false
    disableCursor()
    return  # saltar render parcial del frame anterior
  case game.state:
  of MainMenu:
    let action = drawMainMenu()
    if action == 1:
      game.state = Playing
      disableCursor()
    elif action == 2:
      closeWindow()
  
  of Playing:
    game.player.update(deltaTime)
    game.casino.update(deltaTime)
    if game.exitInputCooldown > 0.0:
      game.exitInputCooldown -= deltaTime
      if game.exitInputCooldown < 0.0: game.exitInputCooldown = 0.0
    # Check for pause (only when not just exited from a machine)
    if isKeyPressed(Escape) and not game.exitingMachine and game.exitInputCooldown == 0.0:
      game.state = Paused
      enableCursor()
    
    # Reset the exiting machine flag after one frame
    if game.exitingMachine:
      game.exitingMachine = false
    
    # Check for machine interaction
    let (nearestMachine, distance) = game.casino.getNearestMachine(game.player.position)
    
    if distance < game.interactionDistance:
      # Draw interaction prompt
      clearBackground(Black)
      
      beginMode3D(game.player.camera)
      game.casino.drawEnvironment()
      game.casino.drawMachines()
      endMode3D()
      
      drawHUD(game.player)
      
      let machineName = case nearestMachine.machineType:
        of RouletteM: "ROULETTE"
        of SlotsM: "SLOTS"
        of BlackjackM: "BLACKJACK"
      
      drawInteractionPrompt("Press [E] to play " & machineName)
      
      if isKeyPressed(E):
        game.activeMachine = case nearestMachine.machineType:
          of RouletteM: 0
          of SlotsM: 1
          of BlackjackM: 2
        
        # Store original camera position
        game.originalCameraPos = game.player.camera.position
        game.originalCameraTarget = game.player.camera.target
        
        # Set target camera based on machine type
        let machinePos = nearestMachine.position
        case nearestMachine.machineType:
        of RouletteM:
          game.targetCameraPos = Vector3(
            x: machinePos.x,
            y: machinePos.y + 3.0,
            z: machinePos.z + 2.5
          )
          game.targetCameraTarget = Vector3(
            x: machinePos.x,
            y: machinePos.y + 0.5,
            z: machinePos.z
          )
        of SlotsM:
          game.targetCameraPos = Vector3(
            x: machinePos.x,
            y: machinePos.y + 2.0,
            z: machinePos.z + 1.5
          )
          game.targetCameraTarget = Vector3(
            x: machinePos.x,
            y: machinePos.y + 1.0,
            z: machinePos.z
          )
        of BlackjackM:
          game.targetCameraPos = Vector3(
            x: machinePos.x,
            y: machinePos.y + 2.5,
            z: machinePos.z + 1.8
          )
          game.targetCameraTarget = Vector3(
            x: machinePos.x,
            y: machinePos.y + 0.5,
            z: machinePos.z
          )
        
        game.state = InMachine
        game.cameraTransition = 0.0
        enableCursor()
    else:
      # Normal rendering
      clearBackground(Black)
      
      beginMode3D(game.player.camera)
      game.casino.drawEnvironment()
      game.casino.drawMachines()
      endMode3D()
      
      drawHUD(game.player)
  
  of InMachine:
    # Animate camera transition
    if game.cameraTransition < 1.0:
      game.cameraTransition += deltaTime * 2.0
      if game.cameraTransition > 1.0:
        game.cameraTransition = 1.0
      
      # Smooth easing
      let t = game.cameraTransition
      let eased = t * t * (3.0 - 2.0 * t)  # Smoothstep
      
      game.player.camera.position = Vector3(
        x: game.originalCameraPos.x + (game.targetCameraPos.x - game.originalCameraPos.x) * eased,
        y: game.originalCameraPos.y + (game.targetCameraPos.y - game.originalCameraPos.y) * eased,
        z: game.originalCameraPos.z + (game.targetCameraPos.z - game.originalCameraPos.z) * eased
      )
      game.player.camera.target = Vector3(
        x: game.originalCameraTarget.x + (game.targetCameraTarget.x - game.originalCameraTarget.x) * eased,
        y: game.originalCameraTarget.y + (game.targetCameraTarget.y - game.originalCameraTarget.y) * eased,
        z: game.originalCameraTarget.z + (game.targetCameraTarget.z - game.originalCameraTarget.z) * eased
      )
    
    clearBackground(Black)
    
    beginMode3D(game.player.camera)
    game.casino.drawEnvironment()
    game.casino.drawMachines()
    endMode3D()
    
    var finished = false
    
    # Machine play returns true when player wants to exit
    case game.activeMachine:
    of 0:
      finished = game.casino.roulette.play(game.player)
    of 1:
      finished = game.casino.slots.play(game.player)
    of 2:
      finished = game.casino.blackjack.play(game.player)
    else:
      finished = true
    
    # When finished, transition camera back
    if finished:
      # Set flag to prevent pause menu from triggering on the same frame
      game.pendingExit = true
      game.exitingMachine = true
      game.exitInputCooldown = 0.18    # 180 ms, ajustar si hace falta
      
      if game.cameraTransition > 0.0:
        game.cameraTransition -= deltaTime * 2.5
        if game.cameraTransition < 0.0:
          game.cameraTransition = 0.0
        
        let t = game.cameraTransition
        let eased = t * t * (3.0 - 2.0 * t)
        
        game.player.camera.position = Vector3(
          x: game.originalCameraPos.x + (game.targetCameraPos.x - game.originalCameraPos.x) * eased,
          y: game.originalCameraPos.y + (game.targetCameraPos.y - game.originalCameraPos.y) * eased,
          z: game.originalCameraPos.z + (game.targetCameraPos.z - game.originalCameraPos.z) * eased
        )
        game.player.camera.target = Vector3(
          x: game.originalCameraTarget.x + (game.targetCameraTarget.x - game.originalCameraTarget.x) * eased,
          y: game.originalCameraTarget.y + (game.targetCameraTarget.y - game.originalCameraTarget.y) * eased,
          z: game.originalCameraTarget.z + (game.targetCameraTarget.z - game.originalCameraTarget.z) * eased
        )
      else:
        game.state = Playing
        game.activeMachine = -1
        disableCursor()
  
  of Paused:
    clearBackground(Black)
    
    # Draw game in background
    beginMode3D(game.player.camera)
    game.casino.drawEnvironment()
    game.casino.drawMachines()
    endMode3D()
    
    # Draw pause overlay
    let screenWidth = getScreenWidth()
    let screenHeight = getScreenHeight()
    
    drawRectangle(0, 0, screenWidth, screenHeight, fade(Black, 0.7))
    
    let title = "PAUSED"
    let titleSize: int32 = 60
    let titleWidth = measureText(title, titleSize)
    drawText(title, screenWidth div 2 - titleWidth div 2, 200, titleSize, Gold)
    
    let instructions = [
      "ESC - Resume",
      "Q - Quit to Menu"
    ]
    
    var yPos: int32 = 320
    for instr in instructions:
      let width = measureText(instr, int32(30))
      drawText(instr, screenWidth div 2 - width div 2, yPos, int32(30), White)
      yPos += 45
    
    if isKeyPressed(Escape):
      game.state = Playing
      disableCursor()
    elif isKeyPressed(Q):
      game.state = MainMenu
      game.player = newPlayer(Vector3(x: 0, y: 1.6, z: 8), 500)
      enableCursor()