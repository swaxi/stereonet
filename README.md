# QFIELD Structural Geology Plugin

## Overview
This QML plugin for QFIELD plots structural geology data on an equal-area stereographic projection (Schmidt net):
- **Poles to Bedding**: Calculated from dip and dip direction measurements
- **Lineations**: Plotted from azimuth and plunge measurements

## Features
- Automatic field detection (case-insensitive)
- Lower hemisphere equal-angle (Wulff) stereographic projection
- Support for multiple field name variations
- Visual stereonet with cardinal directions and reference circles

## Installation

1. Copy `StructuralGeologyPlot.qml` to your QFIELD plugins directory
2. The typical location is:
   - Android: `/sdcard/Android/data/ch.opengis.qfield/files/QField/plugins/`
   - iOS: App's documents directory under `QField/plugins/`
   - Desktop: `~/.qfield/plugins/` or similar

3. Restart QFIELD

## Required Field Names

### For Poles to Bedding:
- `dip` (or `Dip`, `DIP`)
- `dip_direction` (or `DipDirection`, `dipdirection`, `dip direction`, etc.)

### For Lineations:
- `azimuth` (or `Azimuth`, `AZIMUTH`)
- `plunge` (or `Plunge`, `PLUNGE`)

## Usage

1. Select a vector layer containing structural geology measurements
2. Click the "Plot Structure" button
3. The plugin will:
   - Check for required field pairs
   - Extract valid data points
   - Display a stereonet with plotted data
4. If the layer doesn't have the required fields, no plot is generated

## Data Format

### Dip/Dip Direction (Bedding)
- **Dip**: 0-90° (angle from horizontal)
- **Dip Direction**: 0-360° (azimuth of maximum dip)

### Azimuth/Plunge (Lineations)
- **Azimuth**: 0-360° (measured clockwise from North)
- **Plunge**: 0-90° (angle below horizontal)

## Technical Details

- **Projection**: Lower hemisphere equal-area stereographic projection (Schmidt net)
- **Pole Calculation**: Pole to bedding = (dip direction + 90°, 90° - dip)
- **Convention**: Azimuth measured clockwise from North (0°)
- **Rendering**: HTML5 Canvas element for smooth graphics
- **Advantages**: Equal-area projection preserves point density for statistical analysis

## Customization

You can modify the following in the QML code:
- Point color and size (line 124-125)
- Stereonet grid spacing (lines 94-96, 100-106)
- Canvas dimensions (line 54)
- Button appearance (lines 16-24)

## Troubleshooting

**No data plotted:**
- Verify field names match requirements (case-insensitive)
- Check that values are numeric and not null
- Ensure dip values are 0-90° and directions/azimuths are 0-360°

**Button not appearing:**
- Check plugin file location
- Restart QFIELD
- Verify QML syntax (no errors in file)

**Projection looks wrong:**
- Verify azimuth convention (clockwise from North)
- Check that dip direction is the azimuth of maximum dip
- Ensure plunge values are below horizontal (0-90°)

## Example Layer Setup in QGIS

Create a point layer with these attributes:
```
| ID | dip | dip_direction | azimuth | plunge | notes        |
|----|-----|---------------|---------|--------|--------------|
| 1  | 45  | 90           | NULL    | NULL   | Bedding      |
| 2  | 30  | 135          | NULL    | NULL   | Bedding      |
| 3  | NULL| NULL         | 180     | 25     | Lineation    |
| 4  | NULL| NULL         | 45      | 60     | Lineation    |
```

## License
This plugin is provided as-is for geological field data collection and analysis.

## Contributing
Suggestions and improvements are welcome. Consider adding:
- Density contouring
- Great circle plotting for planes
- Export functionality
- Multiple symbol types
- Color coding by attributes
