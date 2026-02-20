# Pause Menu Setup Guide

**Created:** February 13, 2026  
**Script:** `scripts/ui/PauseMenu.gd` ✅ Created

---

## 📋 Overview

This guide will help you set up the pause menu in Godot. The pause menu includes:
- **RunSummaryPanel** at the top (showing current run stats)
- **3 Buttons** (Resume, Settings, Quit) with MainMenu-style gold borders
- **Confirmation Dialog** for quit action
- **Semi-transparent overlay** like VictoryHUD

---

## 🎨 Style Reference

**Button Style** (matches MainMenu):
- Gold Border: `Color(0.858824, 0.721569, 0.329412, 1.0)` - RGB(219, 184, 84)
- Border Width: `8px`
- Background: Transparent
- Font Size: `80`
- Button Width: `600px`
- Spacing: `20px` between buttons

---

## 🛠️ Step-by-Step Setup in Godot Editor

### **Step 1: Open UI.tscn**
1. In Godot, navigate to `scenes/ui/UI.tscn`
2. Double-click to open it in the editor

---

### **Step 2: Create PauseMenu Root Node**
1. In the Scene tree, right-click on the root **"UI"** (CanvasLayer) node
2. Select **"Add Child Node"**
3. Search for **"Control"**
4. Click **"Create"**
5. Rename it to **"PauseMenu"**
6. In the Inspector, set the following properties:
   - **Layout → Anchors Preset:** Select "Full Rect" (top-left icon)
   - **Layout → Anchor Right:** `1.0`
   - **Layout → Anchor Bottom:** `1.0`
   - **Layout → Grow Horizontal:** `2 (Both)`
   - **Layout → Grow Vertical:** `2 (Both)`
   - **Script:** Click folder icon → Navigate to `scripts/ui/PauseMenu.gd` → Open
   - **Process → Mode:** `Always`

---

### **Step 3: Create Overlay (Semi-Transparent Background)**
1. Right-click on **"PauseMenu"** node
2. **Add Child Node** → **"ColorRect"**
3. Rename to **"Overlay"**
4. In Inspector:
   - **Layout → Anchors Preset:** "Full Rect"
   - **Color:** Click the color box → Set to black (`#000000`) → Set **Alpha to 0.45**
   - **Mouse → Filter:** `Stop`

---

### **Step 4: Create Root Container**
1. Right-click on **"PauseMenu"**
2. **Add Child Node** → **"Control"**
3. Rename to **"Root"**
4. In Inspector:
   - **Layout → Anchors Preset:** "Full Rect"
   - **Mouse → Filter:** `Stop`
   - **Process → Mode:** `Always`

---

### **Step 5: Add RunSummaryPanel**
1. Right-click on **"Root"** node
2. Select **"Instantiate Child Scene"**
3. Navigate to `scripts/ui/RunSummaryPanel.tscn`
4. Click **"Open"**
5. The node should be named **"RunSummaryPanel"**
6. In Inspector:
   - **Layout → Layout Mode:** `0 (Position)`
   - **Visible:** Unchecked (✗) - script will show it when needed
   - **Style:** Drag `HUDStyle` resource from another UI element (or leave for script to assign)

---

### **Step 6: Create Buttons Container**
1. Right-click on **"Root"**
2. **Add Child Node** → **"VBoxContainer"**
3. Rename to **"ButtonsContainer"**
4. In Inspector:
   - **Layout → Custom Minimum Size → X:** `600`
   - **Mouse → Filter:** `Pass`
   - **Theme Overrides → Constants → Separation:** `20`

---

### **Step 7: Create Resume Button**
1. Right-click on **"ButtonsContainer"**
2. **Add Child Node** → **"Button"**
3. Rename to **"ResumeButton"**
4. In Inspector:
   - **Text:** `Resume`
   - **Layout → Custom Minimum Size → X:** `600`
   - **Layout → Size Flags → Horizontal:** Check "Shrink Center" (4)
   - **Theme Overrides → Font Sizes → Font Size:** `80`
   
5. **Add Button Styles** (this is the detailed part):
   - Click **"Theme Overrides"** → **"Styles"**
   - Click **"Normal"** → **"StyleBoxFlat"** → **"New StyleBoxFlat"**
   - Click the created StyleBoxFlat to edit it:
     - **Bg Color:** `Color(0.6, 0.6, 0.6, 0)` - Transparent gray
     - **Border → Border Width Left:** `8`
     - **Border → Border Width Top:** `8`
     - **Border → Border Width Right:** `8`
     - **Border → Border Width Bottom:** `8`
     - **Border → Border Color:** `Color(0.858824, 0.721569, 0.329412, 1.0)` - Gold

   - Click **"Hover"** → **"StyleBoxFlat"** → **"New StyleBoxFlat"**
   - Click the created StyleBoxFlat to edit it:
     - **Bg Color:** `Color(0.6, 0.6, 0.6, 0)` - Transparent
     - **Border → Border Width Left:** `8`
     - **Border → Border Width Top:** `8`
     - **Border → Border Width Right:** `8`
     - **Border → Border Width Bottom:** `8`
     - **Border → Border Color:** `Color(0.858824, 0.721569, 0.329412, 1.0)` - Gold
     - **Shadow → Shadow Color:** `Color(0.858824, 0.721569, 0.329412, 0)` - Transparent gold
     - **Shadow → Shadow Size:** `5`

   - Click **"Pressed"**, **"Disabled"**, **"Focus"** → **"StyleBoxEmpty"** → **"New StyleBoxEmpty"**

---

### **Step 8: Create Settings Button** (Repeat Step 7)
1. Duplicate **"ResumeButton"** (Ctrl+D or right-click → Duplicate)
2. Rename to **"SettingsButton"**
3. Change **Text** to `Settings`
4. Move below ResumeButton in hierarchy (drag if needed)

---

### **Step 9: Create Quit Button** (Repeat Step 7)
1. Duplicate **"SettingsButton"** (Ctrl+D)
2. Rename to **"QuitButton"**
3. Change **Text** to `Quit`
4. Move below SettingsButton in hierarchy

---

### **Step 10: Create Confirmation Dialog Container**
1. Right-click on **"Root"**
2. **Add Child Node** → **"Control"**
3. Rename to **"ConfirmDialog"**
4. In Inspector:
   - **Layout → Anchors Preset:** "Full Rect"
   - **Visible:** Unchecked (✗)
   - **Mouse → Filter:** `Stop`

---

### **Step 11: Create Confirmation Dialog Overlay**
1. Right-click on **"ConfirmDialog"**
2. **Add Child Node** → **"ColorRect"**
3. Rename to **"ConfirmOverlay"**
4. In Inspector:
   - **Layout → Anchors Preset:** "Full Rect"
   - **Color:** Black with Alpha `0.7` (darker than main overlay)

---

### **Step 12: Create Confirmation Panel**
1. Right-click on **"ConfirmDialog"**
2. **Add Child Node** → **"Panel"**
3. Rename to **"ConfirmPanel"**
4. In Inspector:
   - **Layout → Anchors Preset:** "Center"
   - **Layout → Custom Minimum Size:** `Vector2(800, 300)`
   - **Position:** `Vector2(-400, -150)` (centered, adjust as needed)
   - **Theme Overrides → Styles → Panel:**
     - Create **"New StyleBoxFlat"**
     - **Bg Color:** `Color(0.07, 0.07, 0.09, 0.95)` (dark background)
     - **Border → Border Width:** `2` (all sides)
     - **Border → Border Color:** `Color(0.18, 0.18, 0.22, 1.0)` (gray border)
     - **Corner Radius:** `10` (all corners)

---

### **Step 13: Create VBox for Confirmation Dialog Content**
1. Right-click on **"ConfirmPanel"**
2. **Add Child Node** → **"VBoxContainer"**
3. Rename to **"VBox"**
4. In Inspector:
   - **Layout → Anchors Preset:** "Full Rect" with margins
   - **Layout → Offset Left:** `20`
   - **Layout → Offset Top:** `20`
   - **Layout → Offset Right:** `-20`
   - **Layout → Offset Bottom:** `-20`
   - **Theme Overrides → Constants → Separation:** `30`

---

### **Step 14: Create Confirmation Label**
1. Right-click on **"VBox"**
2. **Add Child Node** → **"Label"**
3. Rename to **"ConfirmLabel"**
4. In Inspector:
   - **Text:** `Are you sure? Progress will be lost.`
   - **Horizontal Alignment:** `Center`
   - **Vertical Alignment:** `Center`
   - **Layout → Size Flags → Vertical:** Check "Expand" (3)
   - **Theme Overrides → Font Sizes → Font Size:** `60`
   - **Theme Overrides → Colors → Font Color:** `Color(0.95, 0.95, 0.97, 1.0)` (light gray)

---

### **Step 15: Create Buttons HBox**
1. Right-click on **"VBox"**
2. **Add Child Node** → **"HBoxContainer"**
3. Rename to **"ButtonsHBox"**
4. In Inspector:
   - **Alignment → Horizontal:** `Center`
   - **Theme Overrides → Constants → Separation:** `40`

---

### **Step 16: Create Yes Button**
1. Right-click on **"ButtonsHBox"**
2. **Add Child Node** → **"Button"**
3. Rename to **"YesButton"**
4. In Inspector:
   - **Text:** `Yes`
   - **Layout → Custom Minimum Size → X:** `300`
   - **Theme Overrides → Font Sizes → Font Size:** `60`
   - Apply same StyleBoxFlat styles as main buttons (Steps 7), but with:
     - **Border Width:** `6` (slightly thinner)
     - Same gold color for border

---

### **Step 17: Create No Button**
1. Duplicate **"YesButton"** (Ctrl+D)
2. Rename to **"NoButton"**
3. Change **Text** to `No`

---

### **Step 18: Final PauseMenu Node Configuration**
1. Click on the root **"PauseMenu"** node
2. In Inspector, under **"PauseMenu"** script properties (scroll down to Script Variables section):
   - **Style:** Drag the `HUDStyle` resource from another UI element (e.g., from DeathOverlay/RunSummaryPanel)
   - **Design Height:** `1440.0`
   - **Run Summary Top Y Design:** `90.0`
   - **Button Width:** `600.0`
   - **Button Font Size:** `80`
   - **Button Spacing:** `20.0`

---

### **Step 19: Save and Test**
1. **Save the scene** (Ctrl+S)
2. **Run the game** (F5)
3. **Press Escape** (menu action) to open pause menu
4. Test all buttons:
   - **Resume** - Should close menu and unpause
   - **Settings** - Should print message (not implemented yet)
   - **Quit** - Should show confirmation dialog
   - **Yes** - Should return to main menu
   - **No** - Should close dialog

---

## 🎮 Input Configuration

The pause menu uses the **"menu"** input action, which is already configured in `project.godot`:
- **Key:** Escape (physical keycode 4194305)

---

## 🐛 Troubleshooting

### **Issue: Buttons don't have gold borders**
- Make sure you created **StyleBoxFlat** for "Normal" and "Hover" states
- Check that Border Color is set to: `Color(0.858824, 0.721569, 0.329412, 1.0)`

### **Issue: Pause menu doesn't show**
- Make sure `process_mode` is set to `Always` on PauseMenu and Root nodes
- Check that the script is attached to PauseMenu node

### **Issue: RunSummaryPanel doesn't show**
- Make sure HUDStyle resource is assigned in PauseMenu script properties
- Check that RunSummaryPanel scene is properly instantiated

### **Issue: Game doesn't pause**
- Verify that `get_tree().paused = true` is being called (check console for errors)
- Make sure nodes that should pause have `process_mode` set to `Pausable` or `Inherit`

---

## 📝 Alternative: Quick Setup (Scene File)

If the above steps are too detailed, I can also create a complete `.tscn` file for you. However, due to the complexity of scene files and resource references, the manual setup above ensures everything is properly connected.

---

## ✅ Next Steps

After setting up the pause menu:
1. **Test thoroughly** - Open/close, click all buttons
2. **Settings Menu** - We'll implement this next (as mentioned in the script TODO)
3. **Polish** - Add fade-in animations if desired (like VictoryHUD)

---

## 📞 Need Help?

If you encounter any issues or need clarification on any step, let me know!
