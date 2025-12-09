import QtQuick 2.12
import QtQuick.Controls 2.12
import org.qfield 1.0
import org.qgis 1.0

// Compact Structural Geology Stereonet Plugin for QFIELD
Item {
    id: root
    
    Button {
        id: plotButton
        text: "📊 Plot Structures"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        onClicked: processLayer()
    }
    
    Popup {
        id: stereonetPopup
        width: 520
        height: 580
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        
        Column {
            anchors.fill: parent
            spacing: 5
            
            Text {
                id: titleText
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: 16
                font.bold: true
            }
            
            Canvas {
                id: canvas
                width: 500
                height: 500
                property var points: []
                property bool isPoles: false
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    
                    var cx = width / 2
                    var cy = height / 2
                    var r = 230
                    
                    // Outer circle
                    ctx.lineWidth = 2
                    ctx.strokeStyle = "#000"
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.stroke()
                    
                    // Reference circles
                    ctx.lineWidth = 0.5
                    ctx.strokeStyle = "#ccc"
                    for (var i = 1; i < 9; i++) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r * Math.sin(i * 10 * Math.PI / 180), 0, 2 * Math.PI)
                        ctx.stroke()
                    }
                    
                    // Diameters
                    for (var a = 0; a < 360; a += 30) {
                        var rad = a * Math.PI / 180
                        ctx.beginPath()
                        ctx.moveTo(cx, cy)
                        ctx.lineTo(cx + r * Math.cos(rad), cy + r * Math.sin(rad))
                        ctx.stroke()
                    }
                    
                    // Labels
                    ctx.fillStyle = "#000"
                    ctx.font = "bold 14px sans-serif"
                    ctx.textAlign = "center"
                    ctx.fillText("N", cx, cy - r - 10)
                    ctx.fillText("S", cx, cy + r + 18)
                    ctx.fillText("E", cx + r + 12, cy + 5)
                    ctx.fillText("W", cx - r - 12, cy + 5)
                    
                    // Plot points
                    ctx.fillStyle = "rgba(200, 0, 0, 0.7)"
                    for (var j = 0; j < points.length; j++) {
                        var p = points[j]
                        var az, pl
                        
                        if (isPoles) {
                            az = (p.dd + 90) % 360
                            pl = 90 - p.d
                        } else {
                            az = p.az
                            pl = p.pl
                        }
                        
                        var azRad = az * Math.PI / 180
                        var dist = r * Math.sqrt(2) * Math.sin((90 - pl) * Math.PI / 360)
                        var px = cx + dist * Math.sin(azRad)
                        var py = cy - dist * Math.cos(azRad)
                        
                        ctx.beginPath()
                        ctx.arc(px, py, 3, 0, 2 * Math.PI)
                        ctx.fill()
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
    
    function processLayer() {
        var lyr = qgisProject.mapLayer(dashboardModel.currentLayer)
        if (!lyr) {
            showMessage("No layer selected")
            return
        }
        
        var flds = lyr.fields()
        var names = {}
        for (var i = 0; i < flds.count(); i++) {
            var fn = flds.at(i).name()
            names[fn.toLowerCase()] = fn
        }
        
        var hasDip = "dip" in names
        var hasDipDir = ("dip_direction" in names) || ("dipdirection" in names) || ("dip direction" in names)
        var hasAz = "azimuth" in names
        var hasPl = "plunge" in names
        
        var data = []
        var type = ""
        
        if (hasDip && hasDipDir) {
            type = "Poles to Bedding"
            var dipFld = names["dip"]
            var ddFld = names["dip_direction"] || names["dipdirection"] || names["dip direction"]
            
            var iter = lyr.getFeatures()
            var feat
            while (iter.nextFeature(feat)) {
                var dip = feat.attribute(dipFld)
                var dd = feat.attribute(ddFld)
                if (dip !== null && dd !== null && !isNaN(dip) && !isNaN(dd)) {
                    data.push({d: parseFloat(dip), dd: parseFloat(dd)})
                }
            }
            canvas.isPoles = true
            
        } else if (hasAz && hasPl) {
            type = "Lineations"
            var azFld = names["azimuth"]
            var plFld = names["plunge"]
            
            var iter = lyr.getFeatures()
            var feat
            while (iter.nextFeature(feat)) {
                var az = feat.attribute(azFld)
                var pl = feat.attribute(plFld)
                if (az !== null && pl !== null && !isNaN(az) && !isNaN(pl)) {
                    data.push({az: parseFloat(az), pl: parseFloat(pl)})
                }
            }
            canvas.isPoles = false
        } else {
            showMessage("Layer missing required fields:\n• dip + dip_direction OR\n• azimuth + plunge")
            return
        }
        
        if (data.length === 0) {
            showMessage("No valid data found")
            return
        }
        
        titleText.text = type + " (" + data.length + " points) - " + lyr.name()
        canvas.points = data
        canvas.requestPaint()
        stereonetPopup.open()
    }
    
    function showMessage(msg) {
        console.log(msg)
        // Use QFIELD's notification system if available
        if (typeof displayNotification !== 'undefined') {
            displayNotification("Structure Plot", msg, "info")
        }
    }
}
