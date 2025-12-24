<div align="center">

# Quest Data Exporter

![Version](https://img.shields.io/badge/version-v1.2.0-blue.svg)
![WoW Version](https://img.shields.io/badge/WoW-3.3.5a-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-Project%20Ascension-purple.svg)
![Total Downloads](https://img.shields.io/github/downloads/Xurkon/QuestDataExporter/total?style=for-the-badge&label=TOTAL%20DOWNLOADS&color=e67e22)
![Latest Release](https://img.shields.io/github/downloads/Xurkon/QuestDataExporter/latest/total?style=for-the-badge&label=LATEST%20RELEASE&color=3498db)
[![Patreon](https://img.shields.io/badge/Patreon-Support-orange?style=for-the-badge&logo=patreon)](https://patreon.com/Xurkon)
[![PayPal](https://img.shields.io/badge/PayPal-Donate-blue?style=for-the-badge&logo=paypal)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=kancerous@gmail.com)

<br/>

**Comprehensive Quest Database Builder for WoW 3.3.5a Private Servers**

Automatically captures quest data, NPC locations, creature spawns, and item drops as you play. Perfect for building server-specific databases, especially for custom content servers like Project Ascension.

[⬇ **Download Latest**](https://github.com/Xurkon/QuestDataExporter/releases/latest) &nbsp;&nbsp;•&nbsp;&nbsp; [📂 **View Source**](https://github.com/Xurkon/QuestDataExporter) &nbsp;&nbsp;•&nbsp;&nbsp; [📖 **Read Documentation**](https://xurkon.github.io/QuestDataExporter/)

</div>

---

## ✨ Features

### 🔍 Automated Tracking
Automatically records quest names, levels, objectives, descriptions, rewards, and completion status without manual input.

### 🌍 NPC & Location Mapping
Captures precise coordinates for **Quest Givers** and **Turn-in NPCs**, including zone and map IDs.

### ⚔️ Creature & Drop Tracking
Links killed creatures to specific quest objectives and tracks which creatures drop quest items (with drop counts).

### 🤝 Community Sync
Share discoveries in real-time with other players via a hidden chat channel. Automatically merges incoming data to build the database together.

### 📦 Multi-Format Export
Export data in multiple formats:
- **Lua Tables**: For direct use in other addons
- **JSON**: For external web apps and tools
- **Indexed**: Pre-built lookup tables for fast queries
- **Developer Guide**: Complete schema documentation

---

## 📥 Installation

### Manual Install
1. Download the latest release
2. Extract the `QuestDataExporter` folder
3. Place it in your WoW directory:
   ```
   Interface\AddOns\QuestDataExporter\
   ```
4. Restart WoW

---

## 🔧 Usage

Once installed, the addon runs automatically.

### Basic Commands

| Command | Description |
|---------|-------------|
| `/qde` | Show help menu |
| `/qde options` | Open settings window |
| `/qde export` | Open export interface |
| `/qde scan` | Manually scan current quest log |
| `/qde stats` | Show database statistics |
| `/qde clear` | Clear all captured data |

### Sync Commands

| Command | Description |
|---------|-------------|
| `/qde sync` | Request data from channel |
| `/qde sync on/off` | Toggle community sync |
| `/qde sync status` | Show connection status |

---

## 🛠️ For Developers

Quest Data Exporter is designed to be a data source for other tools.

### Data Access
Access the global `QuestDataExport` table in your addon:

```lua
local quest = QuestDataExport.quests["Quest Name"]
print("Quest Level:", quest.level)
print("Starts at:", quest.giverName)
```

See the [Developer Documentation](https://xurkon.github.io/QuestDataExporter/) for the full schema and examples.

---

## 📜 Changelog

See [CHANGELOG.md](CHANGELOG.md) for full version history.

### v1.2.0 - Community Sync
- **Added Community Sync**: Share data with other players in real-time
- **Added Rate Limiting**: Prevents disconnects during large syncs
- **Added Auto-Merge**: Smart merging of incoming community data

### v1.1.0 - Developer Tools
- **Added JSON Export**: Strict JSON format for web tools
- **Added Developer Guide**: Schema export for documentation

---

## ⚖️ License

MIT License - See [LICENSE](LICENSE) for details.

<br/>
<div align="center">
Made with care for the Project Ascension community
</div>
