# ⚡ Capacitor Design Document

### Overview
**Capacitor** is a collaborative first-person horror game for 2-5 players, set in a post-apocalyptic world. Players are cyborgs gathering components to repair their deteriorating bodies. The main gameplay revolves around exploring an abandoned industrial complex, collecting components, and surviving traps and monsters.

---

## 🎮 Game Features

### 🛠 Economy
- **Inventory Slots:** Each player has 4 slots for equipment or loot.
- **Loot Components:**
  - 1-5 components per loot item.
  - Player body = 1 component.
  - Most loot: 2-3 components; Rare loot: 4-5 components.
- **Loot Visibility:** Occasional sheens in dark areas.
- **Player Death Penalty:** 
  - Costs 2 components to reconstruct a player.
  - Components cannot go negative.
- **Self-Repair Mechanic:**
  - Required every 2 in-game days.
  - Cost: `10 + 5 × (number of repairs)`.
  - Failure reduces max HP and stamina by 25%. Second failure results in death.

---

### ⚡ Electricity System
- **Generator:** 
  - Managed with fuel (electricity) and heat levels.
  - Players use coolant to reduce generator heat.
  - BLACKOUT occurs if fuel runs out or generator overheats.
- **Electricity Levels:**
  - `100-75%`: Bright lights; containment cells stay closed.
  - `75-50%`: Dim lights; 30% chance of containment cell timers (10-120s).
  - `50-25%`: Flickering lights; 80% chance of door timers (10-120s).
  - `25-0%`: Heavy flickering; containment cells on timers (10-120s).
- **BLACKOUT Events:**
  - Fog horn sounds, ambient noise stops.
  - All containment doors open, lights go black.
  - 5 monsters spawn immediately.

---

## 🏗 Level Design
- **Randomly Generated Facility** with key features:
  - **Dimensions:** ~2:1:2 ratio.
  - **Room Types:**
	- Standard Rooms: Loot and monster spawns.
	- Locked Rooms: Require keys to access (0-3 doors).
	- Capacitor Rooms: 1-3 rooms with single-use capacitors.
	- Generator Room: Always near the entrance; includes coolant bottles.
	- Surveillance Station: Offers top-down views of players, enemies, and loot.
	- Containment Cells: Contain medium/large monsters.
	- Stairs Room: For vertical movement.
	- Hallways: Connect rooms.
	
---

## 🎒 Items
- **Flashlight** (1 component): Illuminates the area.
- **Walkie-Talkie** (1 component): Enables long-distance communication.
- **Pocket Knife** (1 component): Close-range melee weapon.
- **Lockpicker** (2 components): Instantly opens locks with a beep.
- **Chemlight Box** (1 component): Contains 10 red chemlights for marking areas.

---

## 👾 Enemies
- **Small Enemy:** Wanders; aggros to loud noises (6m) or proximity (3m).
- **Medium Enemy 1:** Chases players; fast but slow to turn.
- **Medium Enemy 2:** Blind; listens for sound; insta-kills on collision.
- **Large Enemy 1:** Faster than players; freezes in light but activates in darkness.
- **Large Enemy 2:** Mimics players; records/replays voice lines.

---

## 🚀 Development Plan

### Week 1
- **Level Design:**
  - Basic room prefabs (standard, stairs, hallways, generator room, etc.).
  - Adjust procedural generation logic.
- **Systems:**
  - Inventory System: 4-slot inventory, flashlight, walkie-talkie, and loot design.
- **Networking:** Sync player movements and inventory.
- **Enemies:** Prototype Small Enemy.

### Week 2
- **Level Design:** Add advanced room types (Capacitor Rooms, Surveillance Stations).
- **Systems:**
  - Electricity mechanics: Fuel, heat, light thresholds.
- **Networking:** Debug player synchronization.
- **Enemies:** Prototype Medium and Large Enemies.

### Week 3
- **Level Design:**
  - Implement spawn logic for loot and coolant bottles.
  - Refine room design.
- **Systems:**
  - Self-repair system and penalties.
  - Equipment purchasing and loot sheen.
- **Networking:** Sync electricity system and player respawns.
- **Enemies:** Integrate spawning logic and BLACKOUT mechanics.

---

## 🎉 DEMO
