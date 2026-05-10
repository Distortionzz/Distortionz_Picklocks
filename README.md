# Distortionz Picklocks

> Premium lockpicking + vehicle search script for Qbox/FiveM — pick locked vehicles anywhere, search for cash / items / dirty money, configurable break chance, high police risk alerts.

![FiveM](https://img.shields.io/badge/FiveM-cerulean-yellow?style=flat-square&labelColor=181b20)
![Qbox](https://img.shields.io/badge/Qbox-required-red?style=flat-square&labelColor=dfb317)
![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)
![Version](https://img.shields.io/github/v/release/Distortionzz/Distortionz_Picklocks?style=flat-square&color=d4aa62&label=version)

---

## Overview

A polished lockpicking + vehicle robbery flow. Players use a lockpick item on any locked vehicle to attempt entry, then can search the vehicle for cash, items, or dirty money — with configurable break chance, repeat-rob protection, and police alerts.

## Features

- Pick any locked vehicle (configurable per class)
- Vehicle search loot table with cash / dirty money / items
- Lockpick break chance per attempt
- High police alert risk on bust
- Per-vehicle robbery cooldown / one-time-rob tracking
- ox_target integration on locked vehicles
- Distortionz Notify support

## Dependencies

| Resource | Required | Purpose |
|---|---|---|
| `qbx_core` | yes | Player data, money |
| `ox_lib` | yes | Skill-check / progress, callbacks |
| `ox_target` | yes | Vehicle interaction |
| `ox_inventory` | yes | Lockpick item, loot rewards |
| `distortionz_notify` | optional | Branded notifications |

## Installation

```cfg
ensure distortionz_picklocks
```

## Configuration

See [`config.lua`](config.lua) for break chance, loot table, police alert chance, cooldowns, and per-class difficulty.

## Credits

- **Author:** Distortionz
- **Framework:** [Qbox Project](https://github.com/Qbox-project)

## License

MIT — see [LICENSE](LICENSE).
