import naylib, random
import game

const
  SCREEN_WIDTH = 1280
  SCREEN_HEIGHT = 720
  TITLE = "Top Hat Casino 3D"

proc main() =
  # Initialize random seed
  randomize()
  
  # Initialize window
  initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, TITLE)
  setTargetFPS(60)
  
  # Create game
  let gameInstance = newGame()
  
  # Main game loop
  while not windowShouldClose():
    gameInstance.update()
  
  # Cleanup
  closeWindow()

when isMainModule:
  main()