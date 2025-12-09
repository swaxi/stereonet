# QField Stereonet Plugin

A structural geology stereonet plugin for QField that plots orientation data on a Schmidt (equal-area) projection.


![Screen image](screen.png)   

## Features

- **Schmidt net** with proper Lambert azimuthal equal-area projection
- **Poles to bedding** from Dip/Dip Direction fields
- **Lineations** from Azimuth/Plunge fields
- **Generation coloring** for multi-phase structural data
- Automatic field name detection

## Installation

1. Upload from zipfile via URL in Qfield App on your device in settings/plugins:
https://github.com/swaxi/stereonet/archive/refs/heads/main.zip    
3. Look for the 🌐 button in the toolbar

## Usage

1. Select a vector layer with structural data
2. Tap the 🌐 button
3. View your data on the stereonet

## Supported Fields

| Data Type | Field Names |
|-----------|-------------|
| Dip | `dip`, `dip_angle` |
| Dip Direction | `dip_dir`, `dip_direction`, `dipdir`, `dd` |
| Azimuth | `azimuth`, `az`, `bearing`, `trend` |
| Plunge | `plunge`, `pl` |
| Generation (optional) | `generation`, `gen`, `phase`, `event`, `set` |

## License

MIT
