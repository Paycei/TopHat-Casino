import raylib, random
import game

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
  while not windowShouldClose():
    beginDrawing()
    gameInstance.update()
    endDrawing()
  closeWindow()

when isMainModule:
  main()