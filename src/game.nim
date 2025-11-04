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

proc newGame*(): Game =
  result = Game()
  result.state = MainMenu
  result.player = newPlayer(Vector3(x: 0, y: 1.6, z: 8), 500)
  result.casino = newCasino()
  result.activeMachine = -1
  result.interactionDistance = 3.0

proc update*(game: Game) =
  let deltaTime = getFrameTime()
  
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
    
    # Check for pause
    if isKeyPressed(Escape):
      game.state = Paused
      enableCursor()
    
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
        game.state = InMachine
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
    clearBackground(Black)
    
    beginMode3D(game.player.camera)
    game.casino.drawEnvironment()
    game.casino.drawMachines()
    endMode3D()
    
    var finished = false
    
    case game.activeMachine:
    of 0:
      finished = game.casino.roulette.play(game.player)
    of 1:
      finished = game.casino.slots.play(game.player)
    of 2:
      finished = game.casino.blackjack.play(game.player)
    else:
      finished = true
    
    if finished:
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