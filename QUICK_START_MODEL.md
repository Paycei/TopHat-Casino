# Quick Start: Download Free Player Model

This guide will help you quickly get a free player model for your casino game.

## Option 1: Mixamo (Recommended - Easy)

1. **Go to Mixamo**: https://www.mixamo.com
2. **Sign in** with Adobe account (free)
3. **Browse Characters**: Click on "Characters" tab
4. **Select a character** you like (e.g., "Malcolm", "Amy", "Remy")
5. **Download**:
   - Click "Download"
   - Format: **glTF Binary (.glb)**
   - Click "Download"
6. **Rename** the downloaded file to `player_model.glb`
7. **Move** it to `C:\TopHat-Casino\player_model.glb`

## Option 2: Sketchfab (Lots of variety)

1. **Go to Sketchfab**: https://sketchfab.com
2. **Search** for "character" or "person"
3. **Filter by**:
   - Downloadable: Yes
   - License: Free to download
4. **Select a model** and click "Download 3D Model"
5. **Download** as "glTF" format
6. **Extract** the downloaded .zip file
7. **Find** the .glb file inside
8. **Rename** to `player_model.glb`
9. **Move** to `C:\TopHat-Casino\player_model.glb`

## Option 3: Poly Pizza (Simple models)

1. **Go to Poly Pizza**: https://poly.pizza
2. **Search** for "character" or "person"
3. **Click** on a model you like
4. **Download** as "GLB"
5. **Rename** to `player_model.glb`
6. **Move** to `C:\TopHat-Casino\player_model.glb`

## Quick Model Recommendations

### Good Starting Models on Mixamo:
- **Malcolm** - Professional looking character
- **Amy** - Casual character
- **Timmy** - Suited character (good for casino theme!)
- **Jasper** - Formal attire

### Search Terms for Sketchfab:
- "low poly character"
- "casino dealer"
- "businessman"
- "formal character"
- "animated character"

## After Downloading

1. Make sure the file is named exactly: `player_model.glb`
2. Place it in: `C:\TopHat-Casino\player_model.glb`
3. Compile and run:
   ```
   cd C:\TopHat-Casino
   nim c -r src\main.nim
   ```

## Testing Your Model

1. Run the game
2. Walk to one of the mirrors:
   - Back wall (center)
   - Right wall
3. You should see your character model in the reflection!
4. If the model looks wrong:
   - Too big/small: Edit `modelScale` in `src\player.nim`
   - Wrong height: Edit `modelOffset.y` in `src\player.nim`

## Model Size Guidelines

If your model appears:
- **Too large**: Set `modelScale = 0.5` or `0.3`
- **Too small**: Set `modelScale = 2.0` or `3.0`
- **Floating**: Decrease `modelOffset.y` (e.g., `-1.2`)
- **Underground**: Increase `modelOffset.y` (e.g., `-0.4`)

## Troubleshooting

**"Failed to load player model" message**:
- Check file path is exactly `C:\TopHat-Casino\player_model.glb`
- Make sure file isn't corrupted (try opening in Windows 3D Viewer)
- Try a different model

**Model appears but looks strange**:
- Some models are oriented differently
- Try adjusting rotation in `drawPlayerModel` function
- Try a different model from a different source

**Can't see model anywhere**:
- Walk to the mirrors - you'll only see yourself in reflections
- The model won't appear in first-person view (by design)

## License Information

When downloading models, always check the license:
- ✅ **CC0 / Public Domain**: Use freely
- ✅ **CC-BY**: Use freely, credit the author
- ⚠️ **CC-BY-NC**: Non-commercial use only
- ❌ **Proprietary**: Check specific terms

For personal/learning projects, most free models are fine!
