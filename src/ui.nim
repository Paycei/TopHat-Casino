import naylib
import utils, player

proc drawHUD*(player: Player) =
  # Money display
  let moneyText = "Money: " & formatMoney(player.money)
  drawText(moneyText, 20, 20, 30, Gold)
  
  # Crosshair
  let centerX = getScreenWidth() div 2
  let centerY = getScreenHeight() div 2
  drawCircle(centerX, centerY, 3, White)
  drawCircleLines(centerX, centerY, 8, White)

proc drawInteractionPrompt*(text: string) =
  let screenWidth = getScreenWidth()
  let screenHeight = getScreenHeight()
  let centerX = screenWidth div 2
  let promptY = (screenHeight * 2) div 3
  
  let fontSize = 25
  let textWidth = measureText(text, fontSize)
  
  # Background
  drawRectangle(centerX - textWidth div 2 - 15, promptY - 10, 
                textWidth + 30, fontSize + 20, fade(Black, 0.7))
  
  # Text
  drawText(text, centerX - textWidth div 2, promptY, fontSize, Yellow)

proc drawMinigameUI*(title: string, player: Player, messages: seq[string]) =
  let screenWidth = getScreenWidth()
  let screenHeight = getScreenHeight()
  
  # Semi-transparent background
  drawRectangle(0, 0, screenWidth, screenHeight, fade(Black, 0.3))
  
  # Title
  let titleSize = 40
  let titleWidth = measureText(title, titleSize)
  drawText(title, screenWidth div 2 - titleWidth div 2, 50, titleSize, Gold)
  
  # Money
  let moneyText = "Money: " & formatMoney(player.money)
  drawText(moneyText, 20, 20, 30, Gold)
  
  # Messages
  var yPos = 150
  for msg in messages:
    let msgWidth = measureText(msg, 25)
    drawText(msg, screenWidth div 2 - msgWidth div 2, yPos, 25, White)
    yPos += 35

proc drawButton*(x, y, width, height: int, text: string, hovered: bool): bool =
  let mousePos = getMousePosition()
  let isHovered = mousePos.x >= x.float and mousePos.x <= (x + width).float and
                  mousePos.y >= y.float and mousePos.y <= (y + height).float
  
  let color = if isHovered: Gold else: DarkGray
  drawRectangle(x, y, width, height, color)
  drawRectangleLines(x, y, width, height, White)
  
  let textWidth = measureText(text, 25)
  drawText(text, x + (width - textWidth) div 2, y + (height - 25) div 2, 25, Black)
  
  return isHovered and isMouseButtonPressed(Left)

proc drawMainMenu*(): int =
  # Returns: 0 = no action, 1 = start game, 2 = quit
  let screenWidth = getScreenWidth()
  let screenHeight = getScreenHeight()
  
  clearBackground(Black)
  
  # Title
  let title = "TOP HAT CASINO 3D"
  let titleSize = 50
  let titleWidth = measureText(title, titleSize)
  drawText(title, screenWidth div 2 - titleWidth div 2, 100, titleSize, Gold)
  
  # Subtitle
  let subtitle = "Try your luck!"
  let subSize = 25
  let subWidth = measureText(subtitle, subSize)
  drawText(subtitle, screenWidth div 2 - subWidth div 2, 170, subSize, LightGray)
  
  # Buttons
  let buttonWidth = 300
  let buttonHeight = 60
  let centerX = screenWidth div 2 - buttonWidth div 2
  
  if drawButton(centerX, 300, buttonWidth, buttonHeight, "START GAME", false):
    return 1
  
  if drawButton(centerX, 380, buttonWidth, buttonHeight, "QUIT", false):
    return 2
  
  # Instructions
  let instructions = [
    "WASD - Move",
    "Mouse - Look around",
    "E - Interact with machines",
    "ESC - Pause/Back"
  ]
  
  var yPos = 500
  for instr in instructions:
    let instrWidth = measureText(instr, 20)
    drawText(instr, screenWidth div 2 - instrWidth div 2, yPos, 20, DarkGray)
    yPos += 30
  
  return 0