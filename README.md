# spz-vehfunc

> Indicators, hazards, headlight flash, taunts, idle cam · `v1.0.1`

## Overview

`spz-vehfunc` is the grab bag of small driving conveniences: turn signals and hazards,
headlight flashing, horn taunts and emotes, an idle showcase camera, and a godmode toggle
for testing.

## Structure

| Side | File | Purpose |
|---|---|---|
| Client | `client/main.lua` | Indicators, hazards, headlight flash, keybinds |
| Client | `client/godmode.lua` | Vehicle damage toggle |
| Client | `client/taunts.lua` | Horn taunts and emotes |
| Client | `client/idlecam.lua` | Idle showcase camera |

## Commands

| Command | Effect |
|---|---|
| `/vehfunc_leftSignal` · `/vehfunc_rightSignal` · `/vehfunc_hazards` | Indicators and hazards (bindable) |
| `+vehfunc_flashHeadlights` / `-vehfunc_flashHeadlights` | Headlight flash keybind |
| `/taunt_horn` · `/emote` | Taunts and emotes |
| `/idlecam` | Toggle the idle camera |

All keybinds are rebindable in Settings → Key Bindings.

## Dependencies

`ox_lib`

---

Part of [SPiceZ-Core](../README.md) · GPL-3.0
