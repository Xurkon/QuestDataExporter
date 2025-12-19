# Changelog

All notable changes to Quest Data Exporter will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.0]

### Added
- **Community Sync**: Real-time data sharing between players via hidden chat channel.
- **Sync Commands**: Added `/qde sync` commands to control data broadcasting.
- **Auto-merge**: Incoming sync data is automatically validated and merged into local database.
- **Rate Limits**: Added throttling to sync messages to prevent disconnects.

## [1.1.0]

### Added
- **Developer Exports**: Added Schema documentation export for external tool developers.
- **JSON Export**: Added strict JSON formatting option for web compatibility.
- **Index Tables**: Added pre-calculated index tables (`questsByZone`, `npcsByZone`) for faster lookups.

### Changed
- Improved coordinate precision for NPC locations.
- Optimized database storage structure to reduce memory usage.

## [1.0.0] - 2024-12-17

### Added

#### Core Features
- **Quest Tracking**: Automatic capture of quest name, level, tag, objectives, and completion status
- **Quest Text Recording**: Full quest descriptions and objective summaries
- **Reward Tracking**: Items, gold, XP, and choice rewards with item IDs and quality
- **NPC Location Recording**: Quest giver and turn-in NPC positions with zone data
- **Creature Mapping**: Links killed creatures to specific quest objectives with coordinates
- **Item Drop Sources**: Tracks which creatures drop quest items with drop counts and locations
- **Objective Progress Detection**: Smart tracking using before/after snapshots

#### Export System
- **Lua Table Export**: Direct Lua format for use in other addons
- **JSON Export**: Standard JSON format for external tools
- **Indexed Export**: Pre-built lookup tables for fast queries
- **Server Metadata**: All exports include expansion, server type, version, locale, and timestamps

#### Options UI
- **Tabbed Interface**: General, Recording, and Sync tabs
- **Recording Controls**: Granular toggles for all data types
- **Live Statistics**: Real-time counters for captured data

#### Slash Commands
- `/qde` - Help and command list
- `/qde options` - Open settings window
- `/qde export` - Open export window
- `/qde scan` - Manual quest log scan
- `/qde stats` - Display database statistics
- `/qde debug` - Toggle verbose debug logging
- `/qde clear` - Clear all captured data

#### Technical
- **WoW 3.3.5a Compatibility**: Tested on Project Ascension
- **SavedVariables Storage**: Persistent database across sessions
