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
                    // Schmidt net uses equatorial Lambert azimuthal equal-area projection
                    // The net shows great circles (longitude lines) curving E-W
                    // and small circles (latitude lines) as curved horizontal arcs
                    
                    ctx.strokeStyle = "#CCCCCC"
                    ctx.lineWidth = 0.5
                    
                    // Clip to primitive circle
                    ctx.save()
                    ctx.beginPath()
                    ctx.arc(cx, cy, R, 0, 2 * Math.PI)
                    ctx.clip()
                    
                    // Draw small circles (latitude lines - horizontal curves)
                    for (var lat = -80; lat <= 80; lat += 10) {
                        if (lat === 0) continue  // Skip equator, drawn separately
                        drawSmallCircleLat(ctx, cx, cy, R, lat)
                    }
                    
                    // Draw great circles (longitude lines - vertical curves from N to S)
                    for (var lon = -80; lon <= 80; lon += 10) {
                        if (lon === 0) continue  // Skip central meridian, drawn separately
                        drawGreatCircleLon(ctx, cx, cy, R, lon)
                    }
                    
                    ctx.restore()
                    
                    // Outer circle (primitive)
                    ctx.lineWidth = 2
                    ctx.strokeStyle = "#000000"
                    ctx.beginPath()
                    ctx.arc(cx, cy, R, 0, 2 * Math.PI)
                    ctx.stroke()
                    
                    // N-S line (central meridian) and E-W line (equator)
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
                
                // Lambert equal-area projection (equatorial aspect)
                // Projects a point on the sphere to the plane
                // lon, lat in radians; returns x, y scaled by R
                function lambertProject(lon, lat, R) {
                    // For equatorial aspect centered at lon=0, lat=0
                    // k' = sqrt(2 / (1 + cos(lat) * cos(lon)))
                    // x = k' * cos(lat) * sin(lon)
                    // y = k' * sin(lat)
                    var cosLat = Math.cos(lat)
                    var sinLat = Math.sin(lat)
                    var cosLon = Math.cos(lon)
                    var sinLon = Math.sin(lon)
                    
                    var denom = 1 + cosLat * cosLon
                    if (denom < 0.0001) return null  // Point on back of sphere
                    
                    var k = Math.sqrt(2 / denom)
                    return {
                        x: R * k * cosLat * sinLon / Math.sqrt(2),
                        y: R * k * sinLat / Math.sqrt(2)
                    }
                }
                
                // Draw a small circle (constant latitude)
                function drawSmallCircleLat(ctx, cx, cy, R, latDeg) {
                    ctx.beginPath()
                    var first = true
                    var lat = latDeg * Math.PI / 180
                    
                    for (var lonDeg = -90; lonDeg <= 90; lonDeg += 2) {
                        var lon = lonDeg * Math.PI / 180
                        var pt = lambertProject(lon, lat, R)
                        if (!pt) continue
                        
                        if (first) {
                            ctx.moveTo(cx + pt.x, cy - pt.y)
                            first = false
                        } else {
                            ctx.lineTo(cx + pt.x, cy - pt.y)
                        }
                    }
                    ctx.stroke()
                }
                
                // Draw a great circle (constant longitude / meridian)
                function drawGreatCircleLon(ctx, cx, cy, R, lonDeg) {
                    ctx.beginPath()
                    var first = true
                    var lon = lonDeg * Math.PI / 180
                    
                    for (var latDeg = -90; latDeg <= 90; latDeg += 2) {
                        var lat = latDeg * Math.PI / 180
                        var pt = lambertProject(lon, lat, R)
                        if (!pt) continue
                        
                        if (first) {
                            ctx.moveTo(cx + pt.x, cy - pt.y)
                            first = false
                        } else {
                            ctx.lineTo(cx + pt.x, cy - pt.y)
                        }
                    }
                    ctx.stroke()
                }
            }
            
            Row {
                id: legendRow
                width: parent.width
                spacing: 15
                visible: canvas.hasGenerations
                anchors.horizontalCenter: parent.horizontalCenter
                
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
                            text: modelData || "Unknown"
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
                            var genKey = (gen !== null && gen !== undefined && gen !== "") ? String(gen) : "Unknown"
                            point.gen = genKey
                            if (generationSet[genKey] === undefined) {
                                generationSet[genKey] = generationList.length
                                generationList.push(genKey)
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
                            var gen2 = feat.attribute(genField)
                            var genKey2 = (gen2 !== null && gen2 !== undefined && gen2 !== "") ? String(gen2) : "Unknown"
                            point.gen = genKey2
                            if (generationSet[genKey2] === undefined) {
                                generationSet[genKey2] = generationList.length
                                generationList.push(genKey2)
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
