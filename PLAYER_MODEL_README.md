# Player Model and Mirror System

## Overview
Your TopHat Casino game now supports:
1. **Player 3D Model** - A .glb model that represents the player character
2. **Mirrors** - Reflective surfaces that show the player model in real-time

## Features Added

### Player Model System
- Load any .glb format 3D model as the player character
- Model automatically follows player movement and rotation
- Adjustable scale and offset for different model sizes
- Model is visible in third-person view (in mirrors and from machine cameras)

### Mirror System
- Real-time reflections using render textures
- Multiple mirrors can be placed throughout the casino
- Mirrors show the player model, machines, and environment
- Configurable size, position, and rotation
- Decorative gold frame around each mirror

## Current Mirror Placements
Two mirrors are currently placed in the casino:
1. **Back Wall Mirror** - Center of the back wall (coordinates: 0, 2.5, -9.8)
2. **Right Wall Mirror** - Right wall facing west (coordinates: 14.8, 2.5, 0)

## How to Add Your Player Model

### Step 1: Get a .glb Model
You need a 3D model in .glb format. You can:
- Download free models from sites like:
  - Sketchfab (https://sketchfab.com)
  - Mixamo (https://www.mixamo.com) - great for character models
  - Poly Pizza (https://poly.pizza)
- Create your own in Blender and export as .glb
- Convert other formats (FBX, OBJ) to .glb using Blender

### Step 2: Place the Model File
1. Save your .glb file as `player_model.glb`
2. Place it in the root directory: `C:\TopHat-Casino\player_model.glb`

### Step 3: Adjust Model Settings (Optional)
If your model appears too big, too small, or at the wrong height, edit `src\player.nim`:

```nim
# In the newPlayer proc:
result.modelScale = 1.0  # Change this value (e.g., 0.5 for half size, 2.0 for double)
result.modelOffset = Vector3(x: 0, y: -0.8, z: 0)  # Adjust Y value for height
```

### Step 4: Compile and Run
```bash
cd C:\TopHat-Casino
nim c -r src\main.nim
```

## Model Recommendations
For best results:
- Use humanoid character models sized around 1.5-2 meters tall
- Models with simple textures work best
- Avoid models with complex animations (static pose is fine)
- Test with free models before purchasing

## Adding More Mirrors

To add additional mirrors, edit `src\casino.nim` in the `newCasino` proc:

```nim
# Add a new mirror
result.mirrors.add(newMirror(
  Vector3(x: 0.0, y: 2.5, z: 9.8),  # Position
  PI,  # Rotation (0 = facing south, PI/2 = west, PI = north, 3*PI/2 = east)
  4.0,  # Width
  3.0   # Height
))
```

## Mirror Positioning Guide
- **X coordinate**: Left (-) to right (+)
- **Y coordinate**: Floor (0) to ceiling (5)
- **Z coordinate**: Front (+) to back (-)
- **Rotation**: 
  - 0 = faces south (toward positive Z)
  - PI/2 = faces west (toward negative X)
  - PI = faces north (toward negative Z)
  - 3*PI/2 = faces east (toward positive X)

## Customization Options

### Mirror Size
Change the width and height parameters:
```nim
newMirror(position, rotation, 6.0, 4.0)  # Larger mirror
```

### Mirror Quality
Edit `src\mirror.nim`:
```nim
# In newMirror proc:
textureSize: int32 = 1024  # Higher = better quality, lower performance
```

### Model Visibility
The player model is rendered:
- In all mirrors (you can see yourself)
- When viewing machines (third-person view)
- NOT in first-person gameplay (feels more natural)

## Troubleshooting

### Model doesn't appear
1. Check the file path is exactly `C:\TopHat-Casino\player_model.glb`
2. Verify the .glb file isn't corrupted (open in Blender)
3. Check console for "Failed to load player model" message

### Model is too big/small
Adjust `modelScale` in `src\player.nim`

### Model is floating/underground
Adjust the Y value in `modelOffset` (negative = lower, positive = higher)

### Mirror shows black
- Make sure mirrors are placed on walls, not in empty space
- Check that mirror rotation faces toward the playable area

### Performance issues
- Reduce mirror `textureSize` from 512 to 256
- Reduce number of mirrors
- Use simpler player models with fewer polygons

## Technical Details
- Mirrors use render-to-texture for reflections
- Reflection camera mirrors the player camera across the mirror plane
- Player model rotation matches player view direction
- System supports multiple mirrors rendering simultaneously

## Future Enhancements
Possible additions you could implement:
- Multiple player models to choose from
- Model animations (walking, idle)
- Mirror frame customization
- Adjustable mirror reflectivity
- Model customization menu
