# Settings Menu Setup Guide

**Created:** February 13, 2026  
**Files Created:**
- ✅ `scripts/ui/SettingsMenu.gd`
- ✅ `scenes/ui/SettingsMenu.tscn`
- ✅ Updated: `scripts/ui/MainMenu.gd`
- ✅ Updated: `scripts/ui/PauseMenu.gd`
- ✅ Updated: `scripts/systems/3DDice.gd`

---

## 🎮 Features Included

### **Audio Settings:**
- 🔊 **Master Volume** (0-100%, controls all audio)
- 🎵 **Music Volume** (0-100%, controls music bus)
- 🎺 **SFX Volume** (0-100%, controls sound effects bus)

### **Display Settings:**
- 🖥️ **Fullscreen** toggle
- 🔄 **VSync** toggle (prevent screen tearing)
- 📐 **Resolution** dropdown (720p, 1080p, 1440p, 4K)

### **Other Features:**
- 💾 **Persistent Settings** - Saved to `user://settings.cfg`
- 🔙 **Context-Aware Back** - Returns to MainMenu or PauseMenu depending on where opened
- ✨ **Button Hover Effects** - Matches MainMenu style

---

## 🛠️ Setup Instructions

### **Part 1: Add Settings to PauseMenu (In Godot Editor)**

1. **Open `scenes/ui/UI.tscn`**

2. **Click on the "PauseMenu" node**

3. **In Inspector, find the "Settings Menu Scene" property**
   - Click the folder icon
   - Navigate to `scenes/ui/SettingsMenu.tscn`
   - Click "Open"

4. **Save the scene** (Ctrl+S)

---

### **Part 2: Add Settings Button to MainMenu**

This requires adding a new button in the MainMenu scene. Here's how:

#### **Step 1: Open MainMenu.tscn**
1. In Godot, open `scenes/ui/MainMenu.tscn`

#### **Step 2: Update 3DDice Script Node Paths**
1. Click on **"CenterContainer"** node (the one with the 3DDice.gd script)
2. In Inspector, find the **exported variables** at the top:
   - **Game Title Label:** Already set
   - **D20 Sprite:** Already set
   - **Start Button:** Already set
   - **Settings Button:** Currently empty - we'll set this after creating the button
   - **Quit Button:** Already set

#### **Step 3: Duplicate Start Button to Create Settings Button**
1. In the Scene tree, find: **CenterContainer → VBoxContainer → VBoxContainer2 → StartButton**
2. **Right-click "StartButton"** → Select **"Duplicate"** (or Ctrl+D)
3. A new button appears, rename it to **"SettingsButton"**
4. **Drag "SettingsButton"** to position it **between StartButton and QuitButton** in the hierarchy
5. Click on **"SettingsButton"**
6. In Inspector, change:
   - **Text:** Change from "Start Game" to `Settings`

#### **Step 4: Connect Settings Button to 3DDice Script**
1. Click on **"CenterContainer"** node again
2. In Inspector, find **"Settings Button"** property
3. Click the **"Assign..." button** (or drag icon)
4. Select: **CenterContainer → VBoxContainer → VBoxContainer2 → SettingsButton**
5. Click "OK"

#### **Step 5: Connect Settings Button Signal to MainMenu**
1. Click on **"SettingsButton"** in the Scene tree
2. Go to the **"Node"** tab (next to Inspector)
3. Find **"Signals"** section
4. Double-click the **"pressed()"** signal
5. In the "Connect to Script" dialog:
   - **Receiver Method:** Type `_on_settings_button_pressed`
   - Click **"Connect"**

#### **Step 6: Assign Settings Menu Scene to MainMenu**
1. Click on the root **"MainMenu"** node (the Control node at the very top)
2. In Inspector, scroll down to **"Main Menu"** script properties
3. Find **"Settings Menu Scene"** property
4. Click the folder icon
5. Navigate to `scenes/ui/SettingsMenu.tscn`
6. Click "Open"

#### **Step 7: Save and Test**
1. **Save the scene** (Ctrl+S)
2. **Run the game** (F5)
3. You should see **three buttons**: Start Game, Settings, Quit Game
4. All should fade in together and have hover effects

---

## 🧪 Testing Checklist

### **From Main Menu:**
- [ ] Three buttons visible (Start, Settings, Quit)
- [ ] All buttons have hover effect (scale to 105%)
- [ ] Click Settings → Opens settings panel
- [ ] Adjust volumes → Hear changes immediately
- [ ] Toggle Fullscreen → Window changes
- [ ] Toggle VSync → Takes effect
- [ ] Change Resolution → Window resizes (if windowed)
- [ ] Click Back → Returns to Main Menu
- [ ] Start game → Settings persist in next session

### **From Pause Menu (In-Game):**
- [ ] Press Escape → Pause menu opens
- [ ] Click Settings → Opens settings panel
- [ ] Settings show current values
- [ ] Adjust settings → Changes apply
- [ ] Click Back → Returns to Pause Menu (not Main Menu!)
- [ ] Click Resume → Game resumes with new settings

### **Settings Persistence:**
- [ ] Change volume to 50%
- [ ] Quit game completely
- [ ] Restart game
- [ ] Open settings → Volume should still be 50%

---

## 🎨 Visual Style

The settings menu uses:
- **Panel:** Dark background `Color(0.07, 0.07, 0.09, 0.95)` with gold border
- **Title:** Gold color `Color(0.858824, 0.721569, 0.329412, 1)` at 80pt
- **Labels:** Light gray `Color(0.7, 0.72, 0.78, 1)` at 50pt
- **Values:** Gold color at 50pt
- **Back Button:** Same style as MainMenu (gold border, hover glow)

---

## 📝 Audio Bus Configuration

**Important:** This settings menu assumes you have audio buses named:
- **Master** (parent bus)
- **Music** (child of Master)
- **SFX** (child of Master)

If these don't exist, you'll need to create them:
1. **Project → Project Settings**
2. **Audio → Buses**
3. Create buses and parent them correctly

---

## 🐛 Troubleshooting

### **Issue: Settings button not in MainMenu**
- Make sure you completed Part 2, Steps 3-5
- Check that button is between StartButton and QuitButton

### **Issue: Settings don't save**
- Check console for save errors
- Verify `user://` directory is writable

### **Issue: Audio doesn't change**
- Verify audio buses exist (Master, Music, SFX)
- Check that music/sounds are routed to correct buses

### **Issue: Resolution doesn't change**
- Only works in windowed mode (fullscreen uses native resolution)
- Try disabling fullscreen first, then change resolution

---

## ✅ What's Next

After testing, you can expand settings with:
- Damage numbers toggle
- Screen shake intensity
- Camera smoothing
- Key rebinding
- Language selection
- Accessibility options

Let me know if you want to add any of these!
