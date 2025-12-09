# QFIELD Structural Geology Plugin - Installation Guide

## Overview
This plugin adds a toolbar button to QFIELD that plots structural geology data on an equal-area stereonet (Schmidt projection).

## What You Need
- `main.qml` - The plugin code
- `metadata.txt` - Plugin metadata

## Installation Methods

### Method 1: App-Wide Plugin (Recommended)
This makes the plugin available in all your QFIELD projects.

**Steps:**

1. **Find your QFIELD app directory:**
   - Open QFIELD
   - Go to Settings → About QField
   - Note the "App directory" path shown
   - The plugins folder is: `[App directory]/plugins/`

2. **Create plugin folder:**
   - Create a new folder: `[App directory]/plugins/structural-geology/`
   - Example paths:
     - Android: `/storage/emulated/0/Android/data/ch.opengis.qfield/files/QField/plugins/structural-geology/`
     - iOS: `[QField Documents]/QField/plugins/structural-geology/`
     - Desktop: `~/.local/share/OPENGIS.ch/QField/plugins/structural-geology/`

3. **Copy files:**
   - Copy `main.qml` to the `structural-geology` folder
   - Copy `metadata.txt` to the `structural-geology` folder

4. **Restart QFIELD**

5. **Enable the plugin:**
   - Go to Settings → Plugins
   - Find "Structural Geology Plot" in the list
   - Enable it

### Method 2: Project Plugin
This makes the plugin available only for a specific project.

**Steps:**

1. **Rename the file:**
   - Rename `main.qml` to match your project file
   - Example: If your project is `field_survey.qgs`, rename to `field_survey.qml`

2. **Place alongside project:**
   - Put the renamed QML file in the same folder as your `.qgs` file
   - Example:
     ```
     my_project/
     ├── field_survey.qgs
     ├── field_survey.qml  ← Your plugin
     └── data/
     ```

3. **Open project in QFIELD:**
   - The plugin will automatically load when you open the project
   - You may be asked to grant permission to load the plugin

## Using the Plugin

1. **Open a layer** with structural geology data in QFIELD

2. **Make sure the layer is active** (selected in the layers panel)

3. **Click the "Plot Structures" button** in the toolbar (looks like a scatter plot icon)

4. **View your stereonet!** The plugin will:
   - Detect if you have dip/dip_direction (poles to bedding)
   - OR detect if you have azimuth/plunge (lineations)
   - Plot the data on an equal-area stereonet

## Required Field Names

Your layer must have ONE of these field combinations:

### Poles to Bedding:
- `dip` (0-90°)
- `dip_direction` or `dipdirection` or `dip direction` (0-360°)

### Lineations:
- `azimuth` (0-360°)
- `plunge` (0-90°)

**Note:** Field names are case-insensitive (DIP, Dip, dip all work)

## Example Data Setup in QGIS

Create a point layer with these attributes:

```
| ID | dip | dip_direction | notes      |
|----|-----|---------------|------------|
| 1  | 45  | 90           | Bedding    |
| 2  | 30  | 135          | Bedding    |
| 3  | 60  | 270          | Bedding    |
```

OR for lineations:

```
| ID | azimuth | plunge | notes      |
|----|---------|--------|------------|
| 1  | 180     | 25     | Lineation  |
| 2  | 45      | 60     | Lineation  |
| 3  | 315     | 35     | Lineation  |
```

## Troubleshooting

### "No layer selected" message
- Make sure you have a vector layer active (highlighted) in the layers panel

### Button doesn't appear
- **App-wide plugin:** Check that files are in correct location and restart QFIELD
- **Project plugin:** Verify the QML file name exactly matches the project file name
- Check Settings → Plugins to enable the plugin

### "Layer requires dip + dip_direction OR azimuth + plunge" message
- Your layer doesn't have the required field names
- Check field names are spelled correctly (case doesn't matter)
- You need BOTH fields in a pair (dip AND dip_direction, or azimuth AND plunge)

### "No valid data points found" message
- Check that your data fields contain numeric values
- Verify values are in correct ranges:
  - Dip: 0-90°
  - Dip direction/Azimuth: 0-360°
  - Plunge: 0-90°
- Make sure values aren't NULL or empty

### Projection looks wrong
- Verify your azimuth/dip direction convention (should be clockwise from North)
- Check that dip direction is the azimuth of maximum dip (not strike)
- Plunge should be measured downward from horizontal

## Plugin Structure

```
structural-geology/
├── main.qml          ← Main plugin code
└── metadata.txt      ← Plugin information
```

## Technical Details

- **Projection Type:** Equal-area (Schmidt) stereographic projection
- **Hemisphere:** Lower hemisphere
- **Azimuth Convention:** Measured clockwise from North (0°)
- **Pole Calculation:** Pole = (dip_direction + 90°, 90° - dip)

## Uninstalling

**App-wide plugin:**
- Delete the `structural-geology` folder from your plugins directory
- Or disable in Settings → Plugins

**Project plugin:**
- Delete the `.qml` file from your project folder

## Support

For issues or questions:
- Check that you're using QFIELD 2.x or later
- Verify your QGIS project loads correctly in QFIELD
- Check the QFIELD log for error messages

## Future Enhancements

Possible additions:
- Density contouring
- Great circle plotting
- Export to image
- Statistics display
- Multiple symbol types
- Color coding by attributes
