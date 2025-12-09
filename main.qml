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
                    ctx.strokeStyle = "#CCCCCC"
                    ctx.lineWidth = 0.5
                    
                    // For a structural geology stereonet (polar aspect, lower hemisphere):
                    // - Small circles are concentric circles (constant plunge/dip)
                    // - Great circles are the curved lines connecting N-S through E or W
                    
                    // Draw small circles (constant plunge) - these ARE concentric circles
                    // in the polar Schmidt projection
                    for (var plunge = 10; plunge < 90; plunge += 10) {
                        // Schmidt formula: r = R * sqrt(2) * sin((90 - plunge)/2)
                        // which equals: r = R * sqrt(2) * cos(plunge/2) for complement
                        var r = R * Math.sqrt(2) * Math.cos(plunge * Math.PI / 180 / 2)
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                        ctx.stroke()
                    }
                    
                    // Draw great circles (planes passing through center)
                    // These appear as arcs connecting opposite points on the primitive
                    for (var strike = 10; strike < 180; strike += 10) {
                        drawGreatCircleArc(ctx, cx, cy, R, strike)
                    }
                    
                    // Outer circle (primitive)
                    ctx.lineWidth = 2
                    ctx.strokeStyle = "#000000"
                    ctx.beginPath()
                    ctx.arc(cx, cy, R, 0, 2 * Math.PI)
                    ctx.stroke()
                    
                    // N-S and E-W reference lines
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
                
                // Draw a great circle arc on the Schmidt net
                // A great circle passes through the center of the sphere
                // On a polar stereonet, it appears as an arc from one edge to the opposite edge
                // strike: the azimuth where the arc crosses the primitive (0-180)
                function drawGreatCircleArc(ctx, cx, cy, R, strike) {
                    ctx.beginPath()
                    var first = true
                    var strikeRad = strike * Math.PI / 180
                    
                    // A great circle with this strike goes from azimuth=strike to azimuth=strike+180
                    // We trace it by varying the dip from 0 to 90 to 0 along the arc
                    // At each point: azimuth changes, plunge goes 0 -> 90 -> 0
                    
                    for (var t = -90; t <= 90; t += 2) {
                        var tRad = t * Math.PI / 180
                        
                        // For a vertical plane with strike azimuth:
                        // The dip at parameter t is: dip = 90 - |t|... no wait
                        // 
                        // Actually, trace the great circle in 3D then project:
                        // Great circle in plane with normal pointing at azimuth (strike+90)
                        
                        // Parameterize: angle t goes from -90 to +90
                        // plunge = |t|, azimuth = strike + (t >= 0 ? 90 : -90) adjusted
                        
                        // Better: use spherical coordinates directly
                        // A great circle perpendicular to azimuth A passes through:
                        // - (az=A-90, pl=0), (az=A, pl=90), (az=A+90, pl=0)
                        
                        // Convert t to position on great circle
                        var plunge = Math.abs(t)
                        var az = strike + (t >= 0 ? 90 : -90)
                        if (plunge === 90) az = strike  // pole of the plane
                        
                        // Actually let's do this properly with 3D coordinates
                        // The great circle is the intersection of the sphere with a vertical plane
                        // striking at 'strike' degrees
                        
                        // Points on this great circle:
                        // x = cos(t) * sin(strike)
                        // y = cos(t) * cos(strike)  
                        // z = sin(t)
                        // where t is the inclination from horizontal (-90 to +90)
                        
                        var x = Math.cos(tRad) * Math.sin(strikeRad)
                        var y = Math.cos(tRad) * Math.cos(strikeRad)
                        var z = Math.sin(tRad)
                        
                        // For lower hemisphere stereonet, we want z <= 0
                        // But we're looking DOWN, so flip: use z >= 0 as "lower" hemisphere
                        // Standard convention: center is nadir (straight down), z+ is down
                        
                        // Schmidt projection (polar aspect, looking down at lower hemisphere):
                        // r = R * sqrt(2) * sqrt(1 - z) / sqrt(2) = R * sqrt(1 - z) ... 
                        // Wait, standard formula: r = R * sqrt(2) * sin(colatitude/2)
                        // colatitude = angle from pole = 90 - latitude
                        // For z = sin(lat), colatitude = 90 - lat = acos(z) approximately
                        
                        // Using: r = R * sqrt(2) * sin((90° - plunge°)/2)
                        // where plunge = elevation from horizontal = t
                        // So for lower hemisphere: we use z <= 0, and plunge = -t
                        
                        // Let's just use the direct formula:
                        // For a point at (azimuth, plunge) in structural geology terms:
                        // Schmidt: r = R * sqrt(2) * sin((90 - plunge)/2 * pi/180)
                        //        = R * sqrt(2) * cos(plunge/2 * pi/180)
                        
                        // Here t represents plunge (angle below horizontal)
                        // t = 0: on the primitive circle (horizontal)
                        // t = 90: at center (vertical down)
                        // t = -90: would be vertical up (not on lower hemisphere)
                        
                        // For lower hemisphere only: t from 0 to 90 for one half,
                        // but great circles go edge to edge through center
                        // So we trace from one side to the other
                        
                        // The trick: a great circle on lower hemisphere goes from
                        // (strike, 0) to (strike+180, 0) passing through center
                        
                        // Use inclination i from 0 to 180:
                        // i=0: point at (strike, plunge=0)
                        // i=90: point at center (plunge=90)
                        // i=180: point at (strike+180, plunge=0)
                        
                        var i = t + 90  // i goes from 0 to 180
                        var iRad = i * Math.PI / 180
                        
                        // Plunge goes 0 -> 90 -> 0
                        var plungeDeg = 90 - Math.abs(90 - i)
                        // Azimuth 
                        var azDeg = (i <= 90) ? strike : (strike + 180)
                        
                        // Project using Schmidt formula
                        var pt = projectPoint(plungeDeg, azDeg, R)
                        
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
