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
    property var mapCanvas: iface.mapCanvas()
    property bool extentOnly: false  // false = all features, true = current view only
    
    property var generationColors: [
        "#E53935", "#1E88E5", "#43A047", "#FB8C00", "#8E24AA",
        "#00ACC1", "#FFB300", "#6D4C41", "#546E7A", "#D81B60"
    ]
    
    Component {
        id: plotButtonComponent
        Button {
            id: plotBtn
            width: 48
            height: 48
            text: plugin.extentOnly ? "🔍" : "🌐"
            font.pixelSize: 24
            background: Rectangle {
                color: plotBtn.pressed ? "#1976D2" : (plugin.extentOnly ? "#FF9800" : "#2196F3")
                radius: 24
                border.color: plugin.extentOnly ? "#E65100" : "#0D47A1"
                border.width: 2
            }
            contentItem: Text {
                text: plotBtn.text
                font: plotBtn.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: "white"
            }
            onClicked: processLayer()
            onPressAndHold: {
                plugin.extentOnly = !plugin.extentOnly
                mainWindow.displayToast(plugin.extentOnly ? "Mode: Current View Only 🔍" : "Mode: All Features 🌐")
            }
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
        height: Math.min(mainWindow.height - 380, 680)
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
                property var planes: []       // For great circles (dip/dipDir)
                property var lineations: []   // For triangles (plunge/azimuth)
                property bool isPoles: false
                property bool hasBoth: false  // Has both planes and lineations
                property var generationMap: ({})
                property bool hasGenerations: false
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    
                    var cx = width / 2
                    var cy = height / 2
                    var R = Math.min(width, height) / 2 - 25
                    
                    drawSchmidtNet(ctx, cx, cy, R)
                    
                    // Clip to primitive circle for data
                    ctx.save()
                    ctx.beginPath()
                    ctx.arc(cx, cy, R, 0, 2 * Math.PI)
                    ctx.clip()
                    
                    // Draw great circles for planes (if hasBoth mode)
                    if (hasBoth && planes.length > 0) {
                        ctx.lineWidth = 2
                        for (var p = 0; p < planes.length; p++) {
                            var plane = planes[p]
                            if (hasGenerations && plane.gen !== undefined) {
                                var genIdx = generationMap[plane.gen]
                                ctx.strokeStyle = genIdx !== undefined ? 
                                    generationColors[genIdx % generationColors.length] : "#333333"
                            } else {
                                ctx.strokeStyle = "#E53935"
                            }
                            drawPlaneGreatCircle(ctx, cx, cy, R, plane.d, plane.dd)
                        }
                    }
                    
                    // Plot data points or lineations
                    ctx.globalAlpha = 0.85
                    var pointsToPlot = hasBoth ? lineations : points
                    
                    for (var j = 0; j < pointsToPlot.length; j++) {
                        var pt = pointsToPlot[j]
                        var az, plunge
                        var isLineation = hasBoth || !isPoles
                        
                        if (!hasBoth && isPoles) {
                            az = (pt.dd + 180) % 360
                            plunge = 90 - pt.d
                        } else {
                            az = pt.az
                            plunge = pt.pl
                        }
                        
                        if (plunge < 0) {
                            plunge = -plunge
                            az = (az + 180) % 360
                        }
                        if (plunge > 90) {
                            plunge = 180 - plunge
                            az = (az + 180) % 360
                        }
                        
                        var proj = projectPoint(plunge, az, R)
                        var px = cx + proj.x
                        var py = cy - proj.y
                        
                        if (hasGenerations && pt.gen !== undefined && pt.gen !== null) {
                            var genIdx = generationMap[pt.gen]
                            ctx.fillStyle = genIdx !== undefined ? 
                                generationColors[genIdx % generationColors.length] : "#333333"
                        } else {
                            ctx.fillStyle = "#E53935"
                        }
                        
                        if (isLineation) {
                            // Draw triangle for lineations
                            drawTriangle(ctx, px, py, 6)
                        } else {
                            // Draw circle for poles
                            ctx.beginPath()
                            ctx.arc(px, py, 4, 0, 2 * Math.PI)
                            ctx.fill()
                        }
                    }
                    ctx.globalAlpha = 1.0
                    ctx.restore()
                }
                
                // Draw a filled triangle centered at x, y
                function drawTriangle(ctx, x, y, size) {
                    ctx.beginPath()
                    ctx.moveTo(x, y - size)  // Top
                    ctx.lineTo(x - size * 0.866, y + size * 0.5)  // Bottom left
                    ctx.lineTo(x + size * 0.866, y + size * 0.5)  // Bottom right
                    ctx.closePath()
                    ctx.fill()
                }
                
                // Draw a great circle for a plane with given dip and dip direction
                function drawPlaneGreatCircle(ctx, cx, cy, R, dip, dipDir) {
                    ctx.beginPath()
                    var first = true
                    
                    var dipRad = dip * Math.PI / 180
                    var dipDirRad = dipDir * Math.PI / 180
                    
                    // A great circle representing a plane can be traced by finding points
                    // where lines in the plane intersect the lower hemisphere
                    // We parameterize by angle around the plane from 0 to 180 degrees
                    
                    for (var angle = 0; angle <= 180; angle += 2) {
                        var angleRad = angle * Math.PI / 180
                        
                        // For a plane with given dip and dip direction:
                        // The plunge of a line in the plane at angle 'angle' from strike is:
                        // plunge = atan(tan(dip) * sin(angle))
                        // The azimuth is: strike + angle (adjusted)
                        
                        // Strike is 90 degrees counterclockwise from dip direction
                        var strike = dipDir - 90
                        
                        // Calculate plunge using the rake formula
                        var plunge = Math.atan(Math.tan(dipRad) * Math.sin(angleRad)) * 180 / Math.PI
                        
                        // Azimuth along the plane
                        var az = strike + angle
                        
                        // Ensure plunge is positive (lower hemisphere)
                        if (plunge < 0) {
                            plunge = -plunge
                            az = az + 180
                        }
                        
                        az = ((az % 360) + 360) % 360
                        
                        var proj = projectPoint(plunge, az, R)
                        
                        if (first) {
                            ctx.moveTo(cx + proj.x, cy - proj.y)
                            first = false
                        } else {
                            ctx.lineTo(cx + proj.x, cy - proj.y)
                        }
                    }
                    ctx.stroke()
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
                        Canvas {
                            width: 14
                            height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.fillStyle = generationColors[index % generationColors.length]
                                
                                if (canvas.hasBoth || !canvas.isPoles) {
                                    // Triangle for lineations
                                    ctx.beginPath()
                                    ctx.moveTo(7, 1)
                                    ctx.lineTo(1, 13)
                                    ctx.lineTo(13, 13)
                                    ctx.closePath()
                                    ctx.fill()
                                } else {
                                    // Circle for poles
                                    ctx.beginPath()
                                    ctx.arc(7, 7, 6, 0, 2 * Math.PI)
                                    ctx.fill()
                                }
                            }
                            Component.onCompleted: requestPaint()
                            Connections {
                                target: canvas
                                function onHasBothChanged() { requestPaint() }
                                function onIsPolesChanged() { requestPaint() }
                            }
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
            
            // Get all features first
            layer.selectAll()
            var allFeatures = layer.selectedFeatures()
            layer.removeSelection()
            
            if (!allFeatures || allFeatures.length === 0) {
                mainWindow.displayToast("No features in layer")
                return
            }
            
            var features = []
            
            // Filter by extent if in extentOnly mode
            if (extentOnly && mapCanvas) {
                // Get layer extent to compare with map extent (handles CRS difference)
                var layerExt = layer.extent
                var mapExt = mapCanvas.mapSettings.visibleExtent
                
                // Determine if we should use layer coords or map coords
                // by checking if layer extent overlaps with map extent
                var useLayerCrs = true
                if (layerExt) {
                    var layerInMapRange = (layerExt.xMinimum < 180 && layerExt.xMinimum > -180)
                    var mapInLayerRange = (mapExt.xMinimum < 180 && mapExt.xMinimum > -180)
                    // If both are in lat/lon range, use map extent directly
                    useLayerCrs = layerInMapRange && mapInLayerRange
                }
                
                var xMin = mapExt.xMinimum
                var xMax = mapExt.xMaximum
                var yMin = mapExt.yMinimum
                var yMax = mapExt.yMaximum
                
                for (var f = 0; f < allFeatures.length; f++) {
                    var feat = allFeatures[f]
                    var geom = feat.geometry
                    
                    if (geom && geom.asWkt) {
                        var wkt = geom.asWkt()
                        // Parse Point(x y)
                        var match = wkt.match(/Point\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)/i)
                        if (match) {
                            var x = parseFloat(match[1])
                            var y = parseFloat(match[2])
                            
                            if (x >= xMin && x <= xMax && y >= yMin && y <= yMax) {
                                features.push(feat)
                            }
                        }
                    }
                }
                
                if (features.length === 0) {
                    mainWindow.displayToast("No features in view (0/" + allFeatures.length + ")")
                    return
                }
            } else {
                features = allFeatures
            }
            
            var fieldNames = features[0].fields.names
            var dipField = findFieldName(fieldNames, ["dip", "dip_angle", "dip_ref"])
            var dipDirField = findFieldName(fieldNames, ["dip_dir", "dip_direction", "dipdirection", "dipdir", "dd", "dipdir_ref"])
            var azField = findFieldName(fieldNames, ["azimuth", "az", "bearing", "trend"])
            var plField = findFieldName(fieldNames, ["plunge", "pl"])
            var genField = findFieldName(fieldNames, ["generation", "gen", "phase", "event", "set"])
            
            var dataPoints = []
            var planeData = []
            var lineationData = []
            var plotType = ""
            var isPoles = false
            var hasBoth = false
            var generationSet = {}
            var generationList = []
            var hasGen = (genField !== null)
            
            // Check if we have BOTH plane and lineation data
            var hasPlaneFields = (dipField && dipDirField)
            var hasLineationFields = (azField && plField)
            
            if (hasPlaneFields && hasLineationFields) {
                // Combined mode: planes as great circles, lineations as triangles
                plotType = "Planes & Lineations"
                hasBoth = true
                
                for (var i = 0; i < features.length; i++) {
                    var feat = features[i]
                    var dip = feat.attribute(dipField)
                    var dipDir = feat.attribute(dipDirField)
                    var azimuth = feat.attribute(azField)
                    var plunge = feat.attribute(plField)
                    
                    var genKey = "Unknown"
                    if (hasGen) {
                        var gen = feat.attribute(genField)
                        genKey = (gen !== null && gen !== undefined && gen !== "") ? String(gen) : "Unknown"
                        if (generationSet[genKey] === undefined) {
                            generationSet[genKey] = generationList.length
                            generationList.push(genKey)
                        }
                    }
                    
                    // Add plane if valid
                    if (dip !== null && dip !== undefined && 
                        dipDir !== null && dipDir !== undefined &&
                        !isNaN(parseFloat(dip)) && !isNaN(parseFloat(dipDir))) {
                        var plane = { d: parseFloat(dip), dd: parseFloat(dipDir) }
                        if (hasGen) plane.gen = genKey
                        planeData.push(plane)
                    }
                    
                    // Add lineation if valid
                    if (azimuth !== null && azimuth !== undefined && 
                        plunge !== null && plunge !== undefined &&
                        !isNaN(parseFloat(azimuth)) && !isNaN(parseFloat(plunge))) {
                        var lin = { az: parseFloat(azimuth), pl: parseFloat(plunge) }
                        if (hasGen) lin.gen = genKey
                        lineationData.push(lin)
                    }
                }
                
            } else if (hasPlaneFields) {
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
            } else if (hasLineationFields) {
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
            
            // Check we have data
            if (hasBoth) {
                if (planeData.length === 0 && lineationData.length === 0) {
                    mainWindow.displayToast("No valid data points")
                    return
                }
            } else if (dataPoints.length === 0) {
                mainWindow.displayToast("No valid data points")
                return
            }
            
            canvas.points = dataPoints
            canvas.planes = planeData
            canvas.lineations = lineationData
            canvas.isPoles = isPoles
            canvas.hasBoth = hasBoth
            canvas.generationMap = generationSet
            canvas.hasGenerations = (generationList.length > 0)
            legendRepeater.model = generationList
            
            var countInfo = hasBoth ? 
                "(" + planeData.length + " planes, " + lineationData.length + " lins)" :
                "(" + dataPoints.length + " pts)"
            var genInfo = canvas.hasGenerations ? " - " + generationList.length + " gens" : ""
            var viewMode = extentOnly ? " [View]" : ""
            
            titleText.text = plotType + " " + countInfo + genInfo + viewMode + "\n" + layer.name
            
            canvas.requestPaint()
            stereonetPopup.open()
            
        } catch (error) {
            try { layer.removeSelection() } catch(e) {}
            mainWindow.displayToast("Error: " + error.toString())
        }
    }
}
