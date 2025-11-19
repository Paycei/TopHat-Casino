import raylib, random
import game, player, casino

const
  SCREEN_WIDTH = 1280
  SCREEN_HEIGHT = 720
  TITLE = "TopHat CASINO"

proc main() =
  randomize()
  initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, TITLE)
  setTargetFPS(60)
  setExitKey(Null)  # Disable ESC from closing window
  let gameInstance = newGame()
  
  # Try to load player model (place a .glb file in the game directory)
  gameInstance.player.loadPlayerModel("player_model.glb")
  
  while not windowShouldClose():
    beginDrawing()
    gameInstance.update()
    endDrawing()
  
  # Cleanup
  gameInstance.player.unloadPlayerModel()
  gameInstance.casino.unloadCasino()
  
  closeWindow()

when isMainModule:
  main()