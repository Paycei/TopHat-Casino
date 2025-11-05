import raylib, random
import game

const
  SCREEN_WIDTH = 1280
  SCREEN_HEIGHT = 720
  TITLE = "Top Hat Casino"

proc main() =
  # Initialize random seed
  randomize()
  
  # Initialize window
  initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, TITLE)
  setTargetFPS(60)
  setExitKey(Null)  # Disable ESC from closing window
  
  # Create game
  let gameInstance = newGame()
  
  # Main game loop
  while not windowShouldClose():
    beginDrawing()
    gameInstance.update()
    endDrawing()
  
  # Cleanup
  closeWindow()

when isMainModule:
  main()