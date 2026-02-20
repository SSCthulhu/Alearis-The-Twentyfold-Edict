# Audio Bus Setup Guide

**Issue:** Settings menu needs "Music" and "SFX" audio buses to function properly.

---

## 🎵 Quick Setup (2 minutes)

### **Step 1: Open Audio Bus Editor**
1. In Godot, go to the bottom-left panel (next to Output/Debugger)
2. Click on the **"Audio"** tab
3. You should see at least one bus called **"Master"**

### **Step 2: Add Music Bus**
1. Click the **"Add Bus"** button (+ icon) at the top
2. A new bus appears - **double-click its name** to rename it
3. Type `Music` (case-sensitive!)
4. Press Enter

### **Step 3: Add SFX Bus**
1. Click **"Add Bus"** again
2. **Double-click the new bus** to rename it
3. Type `SFX` (case-sensitive!)
4. Press Enter

### **Step 4: Set Bus Parents (Important!)**
Both buses should be children of Master:
1. Click on the **"Music"** bus
2. In the Inspector on the right, find **"Bus"** section
3. Set **"Send"** to `Master`
4. Repeat for **"SFX"** bus

### **Step 5: Save Project**
1. **File → Save** (Ctrl+S)
2. The buses are now configured!

---

## 🎮 Testing

1. Run the game
2. Open Settings menu
3. Adjust volume sliders - **no errors should appear!**
4. Music and SFX should now control their respective buses independently

---

## 🔧 What if I already have audio?

If you already have music or sounds playing in your game:

1. **Find AudioStreamPlayer nodes** in your scenes
2. In Inspector, look for the **"Bus"** property
3. Set it to:
   - `Music` for background music
   - `SFX` for sound effects
   - `Master` for anything else

Example:
- MainMenu music → Set bus to `Music`
- Combat sounds → Set bus to `SFX`
- UI clicks → Set bus to `SFX`

---

## 📋 Bus Structure Should Look Like This:

```
Master (parent)
├── Music (child of Master)
└── SFX (child of Master)
```

This allows:
- **Master** controls overall volume
- **Music** controls only music (independent of SFX)
- **SFX** controls only sound effects (independent of Music)

---

## ✅ Verification

After setup, you should see in the Audio tab:
- ✅ Master bus (volume: 0 dB)
- ✅ Music bus (send: Master)
- ✅ SFX bus (send: Master)

Settings menu will now work without errors!
