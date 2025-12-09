import QtQuick
import QtQuick.Controls
import org.qfield
import org.qgis

// Structural Geology Stereonet Plugin for QFIELD
// Schmidt (Equal-Area / Lambert Azimuthal) Projection
Item {
    id: plugin
    
    property var mainWindow: iface.mainWindow()
    property var dashBoard: iface.findItemByObjectName('dashBoard')
    
    property var generationColors: [
        "#E53935", "#1E88E5", "#43A047", "#FB8C00", "#8E24AA",
        "#00ACC1", "#FFB300", "#6D4C41", "#546E7A", "#D81B60"
    ]
    
    Component {
        id: plotButtonComponent
        Button {
            width: 48
            height: 48
            text: "🌐"
            font.pixelSize: 24
            background: Rectangle {
                color: parent.pressed ? "#1976D2" : "#2196F3"
                radius: 4
                border.color: "#0D47A1"
                border.width: 2
            }
            contentItem: Text {
                text: parent.text
                font: parent.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: "white"
            }
            onClicked: processLayer()
        }
    }
    
    Component.onCompleted: {
        Qt.callLater(function() {
            var btn = plotButtonComponent.createObject(plugin)
            if (btn) {
                iface.addItemToPluginsToolbar(btn)
                mainWindow.displayToast("✓ Stereonet Plugin Loaded")
            }
        })
    }
    
    Popup {
        id: stereonetPopup
        parent: mainWindow.contentItem
        width: Math.min(mainWindow.width - 40, 540)
        height: Math.min(mainWindow.height - 40, 680)
        x: (mainWindow.width - width) / 2
        y: (mainWindow.height - height) / 2
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        background: Rectangle {
            color: "#FFFFFF"
            border.color: "#2196F3"
            border.width: 2
            radius: 4
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            
            Text {
                id: titleText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 16
                font.bold: true
                color: "#000000"
                wrapMode: Text.WordWrap
            }
            
            Canvas {
                id: canvas
                width: Math.min(parent.width, 500)
                height: Math.min(parent.width, 500)
                anchors.horizontalCenter: parent.horizontalCenter
                
                property var points: []
                property bool isPoles: false
                property var generationMap: ({})
                property bool hasGenerations: false
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    
                    var cx = width / 2
                    var cy = height / 2
                    var R = Math.min(width, height) / 2 - 25
                    
                    drawSchmidtNet(ctx, cx, cy, R)
                    
                    // Plot data points
                    ctx.globalAlpha = 0.85
                    for (var j = 0; j < points.length; j++) {
                        var p = points[j]
                        var az, plunge
                        
                        if (isPoles) {
                            az = (p.dd + 180) % 360
                            plunge = 90 - p.d
                        } else {
                            az = p.az
                            plunge = p.pl
                        }
                        
                        if (plunge < 0) {
                            plunge = -plunge
                            az = (az + 180) % 360
                        }
                        if (plunge > 90) plunge = 90
                        
                        var pt = projectPoint(plunge, az, R)
                        var px = cx + pt.x
                        var py = cy - pt.y
                        
                        if (hasGenerations && p.gen !== undefined && p.gen !== null) {
                            var genIdx = generationMap[p.gen]
                            ctx.fillStyle = genIdx !== undefined ? 
                                generationColors[genIdx % generationColors.length] : "#333333"
                        } else {
                            ctx.fillStyle = "#E53935"
                        }
                        
                        ctx.beginPath()
                        ctx.arc(px, py, 4, 0, 2 * Math.PI)
                        ctx.fill()
                    }
                    ctx.globalAlpha = 1.0
                }
                
                // Schmidt (Lambert equal-area) projection
                // Input: plunge (0-90), azimuth (0-360) in degrees
                // Output: {x, y} coordinates where R=1 is the primitive circle
                function projectPoint(plunge, azimuth, R) {
                    var plungeRad = plunge * Math.PI / 180
                    var azRad = azimuth * Math.PI / 180
                    // Schmidt formula: r = R * sqrt(2) * sin((90° - plunge) / 2)
                    var r = R * Math.sqrt(2) * Math.sin((Math.PI/2 - plungeRad) / 2)
                    return {
                        x: r * Math.sin(azRad),
                        y: r * Math.cos(azRad)
                    }
                }
                
                function drawSchmidtNet(ctx, cx, cy, R) {
                    // Clip to primitive circle
                    ctx.save()
                    ctx.beginPath()
                    ctx.arc(cx, cy, R + 1, 0, 2 * Math.PI)
                    ctx.clip()
                    
                    ctx.strokeStyle = "#CCCCCC"
                    ctx.lineWidth = 0.5
                    
                    // Draw small circles (circles of constant latitude/plunge)
                    // These are concentric circles in the polar stereonet
                    for (var lat = 10; lat < 90; lat += 10) {
                        drawSmallCircle(ctx, cx, cy, R, lat)
                    }
                    
                    // Draw great circles (meridians in the equatorial stereonet)
                    // These go from N to S pole, curving E or W
                    for (var lon = 10; lon <= 80; lon += 10) {
                        drawGreatCircle(ctx, cx, cy, R, lon)
                        drawGreatCircle(ctx, cx, cy, R, -lon)
                    }
                    
                    ctx.restore()
                    
                    // Outer circle (primitive)
                    ctx.lineWidth = 2
                    ctx.strokeStyle = "#000000"
                    ctx.beginPath()
                    ctx.arc(cx, cy, R, 0, 2 * Math.PI)
                    ctx.stroke()
                    
                    // N-S and E-W reference lines (central great circle and equator)
                    ctx.lineWidth = 0.5
                    ctx.strokeStyle = "#999999"
                    ctx.beginPath()
                    ctx.moveTo(cx, cy - R)
                    ctx.lineTo(cx, cy + R)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(cx - R, cy)
                    ctx.lineTo(cx + R, cy)
                    ctx.stroke()
                    
                    // Cardinal labels
                    ctx.fillStyle = "#000000"
                    ctx.font = "bold 14px sans-serif"
                    ctx.textAlign = "center"
                    ctx.textBaseline = "middle"
                    ctx.fillText("N", cx, cy - R - 12)
                    ctx.fillText("S", cx, cy + R + 12)
                    ctx.fillText("E", cx + R + 12, cy)
                    ctx.fillText("W", cx - R - 12, cy)
                }
                
                // Draw a small circle (constant latitude/plunge) on the Schmidt net
                // lat: latitude in degrees (0 = equator, 90 = pole)
                function drawSmallCircle(ctx, cx, cy, R, lat) {
                    ctx.beginPath()
                    var first = true
                    var latRad = lat * Math.PI / 180
                    
                    // Trace around the small circle by varying longitude
                    for (var lon = 0; lon <= 360; lon += 3) {
                        var lonRad = lon * Math.PI / 180
                        
                        // Convert spherical (lon, lat) to Cartesian on unit sphere
                        // Using standard geographic convention
                        var x = Math.cos(latRad) * Math.sin(lonRad)
                        var y = Math.cos(latRad) * Math.cos(lonRad)
                        var z = Math.sin(latRad)
                        
                        // Lambert equal-area projection (equatorial aspect, center at -Y axis)
                        // Project from sphere to plane
                        var denom = 1 - y  // 1 + cos(angular distance from center)
                        if (denom < 0.0001) continue  // Skip points at the back
                        
                        var k = Math.sqrt(2 / denom)
                        var px = R * k * x / 2
                        var py = R * k * z / 2
                        
                        if (first) {
                            ctx.moveTo(cx + px, cy - py)
                            first = false
                        } else {
                            ctx.lineTo(cx + px, cy - py)
                        }
                    }
                    ctx.stroke()
                }
                
                // Draw a great circle (meridian) on the Schmidt net
                // lon: longitude in degrees from center (-90 to +90 visible)
                function drawGreatCircle(ctx, cx, cy, R, lon) {
                    ctx.beginPath()
                    var first = true
                    var lonRad = lon * Math.PI / 180
                    
                    // Trace along the great circle by varying latitude from -90 to +90
                    for (var lat = -90; lat <= 90; lat += 2) {
                        var latRad = lat * Math.PI / 180
                        
                        // Convert spherical (lon, lat) to Cartesian on unit sphere
                        var x = Math.cos(latRad) * Math.sin(lonRad)
                        var y = Math.cos(latRad) * Math.cos(lonRad)
                        var z = Math.sin(latRad)
                        
                        // Only draw front hemisphere (y >= 0 means front)
                        if (y < -0.001) continue
                        
                        // Lambert equal-area projection (equatorial aspect)
                        var denom = 1 + y
                        if (denom < 0.0001) continue
                        
                        var k = Math.sqrt(2 / denom)
                        var px = R * k * x / 2
                        var py = R * k * z / 2
                        
                        if (first) {
                            ctx.moveTo(cx + px, cy - py)
                            first = false
                        } else {
                            ctx.lineTo(cx + px, cy - py)
                        }
                    }
                    ctx.stroke()
                }
            }
            
            Flow {
                id: legendFlow
                width: parent.width
                spacing: 10
                visible: canvas.hasGenerations
                
                Repeater {
                    id: legendRepeater
                    model: []
                    Row {
                        spacing: 4
                        Rectangle {
                            width: 12; height: 12; radius: 6
                            color: generationColors[index % generationColors.length]
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData
                            font.pixelSize: 12
                            color: "#333333"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
            
            Button {
                text: "Close"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: stereonetPopup.close()
            }
        }
    }
    
    function findFieldName(fieldNames, candidates) {
        for (var i = 0; i < fieldNames.length; i++) {
            var fn = fieldNames[i].toLowerCase()
            for (var j = 0; j < candidates.length; j++) {
                if (fn === candidates[j].toLowerCase()) return fieldNames[i]
            }
        }
        return null
    }
    
    function processLayer() {
        try {
            if (!dashBoard) dashBoard = iface.findItemByObjectName('dashBoard')
            var layer = dashBoard ? dashBoard.activeLayer : null
            
            if (!layer) { mainWindow.displayToast("No layer selected"); return }
            if (layer.type !== 0) { mainWindow.displayToast("Not a vector layer"); return }
            
            layer.selectAll()
            var features = layer.selectedFeatures()
            
            if (!features || features.length === 0) {
                layer.removeSelection()
                mainWindow.displayToast("No features in layer")
                return
            }
            
            var fieldNames = features[0].fields.names
            var dipField = findFieldName(fieldNames, ["dip", "dip_angle"])
            var dipDirField = findFieldName(fieldNames, ["dip_dir", "dip_direction", "dipdirection", "dipdir", "dd"])
            var azField = findFieldName(fieldNames, ["azimuth", "az", "bearing", "trend"])
            var plField = findFieldName(fieldNames, ["plunge", "pl"])
            var genField = findFieldName(fieldNames, ["generation", "gen", "phase", "event", "set"])
            
            var dataPoints = []
            var plotType = ""
            var isPoles = false
            var generationSet = {}
            var generationList = []
            var hasGen = (genField !== null)
            
            if (dipField && dipDirField) {
                plotType = "Poles to Bedding"
                isPoles = true
                
                for (var i = 0; i < features.length; i++) {
                    var feat = features[i]
                    var dip = feat.attribute(dipField)
                    var dipDir = feat.attribute(dipDirField)
                    
                    if (dip !== null && dip !== undefined && 
                        dipDir !== null && dipDir !== undefined &&
                        !isNaN(parseFloat(dip)) && !isNaN(parseFloat(dipDir))) {
                        
                        var point = { d: parseFloat(dip), dd: parseFloat(dipDir) }
                        
                        if (hasGen) {
                            var gen = feat.attribute(genField)
                            if (gen !== null && gen !== undefined) {
                                point.gen = gen
                                if (generationSet[gen] === undefined) {
                                    generationSet[gen] = generationList.length
                                    generationList.push(String(gen))
                                }
                            }
                        }
                        dataPoints.push(point)
                    }
                }
            } else if (azField && plField) {
                plotType = "Lineations"
                isPoles = false
                
                for (var i = 0; i < features.length; i++) {
                    var feat = features[i]
                    var azimuth = feat.attribute(azField)
                    var plunge = feat.attribute(plField)
                    
                    if (azimuth !== null && azimuth !== undefined && 
                        plunge !== null && plunge !== undefined &&
                        !isNaN(parseFloat(azimuth)) && !isNaN(parseFloat(plunge))) {
                        
                        var point = { az: parseFloat(azimuth), pl: parseFloat(plunge) }
                        
                        if (hasGen) {
                            var gen = feat.attribute(genField)
                            if (gen !== null && gen !== undefined) {
                                point.gen = gen
                                if (generationSet[gen] === undefined) {
                                    generationSet[gen] = generationList.length
                                    generationList.push(String(gen))
                                }
                            }
                        }
                        dataPoints.push(point)
                    }
                }
            } else {
                layer.removeSelection()
                mainWindow.displayToast("Need: Dip + Dip_Dir OR Azimuth + Plunge")
                return
            }
            
            layer.removeSelection()
            
            if (dataPoints.length === 0) {
                mainWindow.displayToast("No valid data points")
                return
            }
            
            canvas.points = dataPoints
            canvas.isPoles = isPoles
            canvas.generationMap = generationSet
            canvas.hasGenerations = (generationList.length > 0)
            legendRepeater.model = generationList
            
            var genInfo = canvas.hasGenerations ? " - " + generationList.length + " gens" : ""
            titleText.text = plotType + " (" + dataPoints.length + " pts)" + genInfo + "\n" + layer.name
            
            canvas.requestPaint()
            stereonetPopup.open()
            
        } catch (error) {
            try { layer.removeSelection() } catch(e) {}
            mainWindow.displayToast("Error: " + error.toString())
        }
    }
}
