import AppKit
import SceneKit

class PetSCNView: SCNView {
    var modelContainer: SCNNode?
    var cameraNode: SCNNode?
    var onClickModel: (() -> Void)?
    var onDoubleClickModel: (() -> Void)?
    var onModelTouched: (() -> Void)?
    private var isDragging = false
    private var lastDragScreen: NSPoint = .zero
    private var rotationY: CGFloat = 0
    private var baseRotationX: CGFloat = -.pi / 2
    private var rotationX: CGFloat = 0

    override var acceptsFirstResponder: Bool { true }
    override var acceptsTouchEvents: Bool { get { true } set {} }

    override func mouseDown(with event: NSEvent) {
        isDragging = false
        lastDragScreen = NSEvent.mouseLocation
        let loc = convert(event.locationInWindow, from: nil)
        let hits = hitTest(loc, options: nil)
        if !hits.isEmpty {
            onModelTouched?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        isDragging = true
        guard let container = modelContainer, let cam = cameraNode else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - lastDragScreen.x
        let dy = current.y - lastDragScreen.y
        lastDragScreen = current
        let fov = cam.camera?.fieldOfView ?? 30
        let dist = CGFloat(cam.position.z)
        let scale = 2.0 * dist * tan(fov * .pi / 360.0) / bounds.height
        container.position.x += CGFloat(dx * scale)
        container.position.y += CGFloat(dy * scale)
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            let loc = convert(event.locationInWindow, from: nil)
            let hits = hitTest(loc, options: nil)
            if !hits.isEmpty {
                if event.clickCount >= 2 {
                    onDoubleClickModel?()
                } else {
                    onClickModel?()
                }
                onModelTouched?()
            }
        }
        isDragging = false
    }

    private func isHeadNode(_ node: SCNNode) -> Bool {
        var current: SCNNode? = node
        while let n = current {
            if let name = n.name {
                let lower = name.lowercased()
                if lower.contains("head") || lower.contains("face") || lower.contains("cheek")
                    || lower.contains("hair") || lower.contains("ear") || lower.contains("ahoge") {
                    return true
                }
            }
            if let geo = n.geometry {
                for mat in geo.materials {
                    if let mname = mat.name?.lowercased(),
                       mname.contains("face") || mname.contains("cheek") || mname.contains("hair") {
                        return true
                    }
                }
            }
            current = n.parent
        }
        return false
    }

    func doScroll(dx: CGFloat, dy: CGFloat) {
        rotationY += dx * 0.005
        rotationX += dy * 0.005
        modelContainer?.eulerAngles = SCNVector3(baseRotationX + rotationX, rotationY, 0)
    }

    func doMagnify(_ magnification: CGFloat) {
        guard let container = modelContainer else { return }
        let s = CGFloat(container.scale.x)
        let newScale = max(0.001, min(10.0, s * (1.0 + magnification)))
        container.scale = SCNVector3(newScale, newScale, newScale)
    }

    func modelScreenPosition() -> NSPoint {
        guard let container = modelContainer else {
            return NSPoint(x: NSScreen.main!.frame.midX, y: NSScreen.main!.frame.midY)
        }
        let projected = projectPoint(container.position)
        let viewPoint = NSPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
        let windowPoint = convert(viewPoint, to: nil)
        return window?.convertPoint(toScreen: windowPoint) ?? viewPoint
    }

    func headScreenPosition() -> NSPoint {
        guard let container = modelContainer else {
            return modelScreenPosition()
        }
        let (minB, maxB) = container.boundingBox
        // Project all 8 corners of bounding box to find visual top-right
        let corners = [
            SCNVector3(minB.x, minB.y, minB.z), SCNVector3(maxB.x, minB.y, minB.z),
            SCNVector3(minB.x, maxB.y, minB.z), SCNVector3(maxB.x, maxB.y, minB.z),
            SCNVector3(minB.x, minB.y, maxB.z), SCNVector3(maxB.x, minB.y, maxB.z),
            SCNVector3(minB.x, maxB.y, maxB.z), SCNVector3(maxB.x, maxB.y, maxB.z),
        ]
        var maxScreenY: CGFloat = -10000
        var maxScreenX: CGFloat = -10000
        for corner in corners {
            let world = container.convertPosition(corner, to: nil)
            let proj = projectPoint(world)
            let vp = NSPoint(x: CGFloat(proj.x), y: CGFloat(proj.y))
            let wp = convert(vp, to: nil)
            let sp = window?.convertPoint(toScreen: wp) ?? vp
            if sp.y > maxScreenY { maxScreenY = sp.y }
            if sp.x > maxScreenX { maxScreenX = sp.x }
        }
        return NSPoint(x: maxScreenX, y: maxScreenY)
    }
}
