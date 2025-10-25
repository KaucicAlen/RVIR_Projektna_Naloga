//
//  ARPageView.swift
//  ARTest
//
//  Created by Alen Kaucic on 24. 10. 25.
//

import Combine
import SwiftUI
import RealityKit
import ARKit

struct ARPageView: View {
    
    @State private var waypoints: [SIMD3<Float>] = []
    
    var body: some View {
        ZStack {
            ARViewContainer(waypoints: $waypoints)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                SwiftUIView()
                    .frame(height: 300)
                    .background(Color.black.opacity(0.0))
                Spacer()
            }
            VStack {
                Spacer()
                Button(action: {
                    TapCoordinator.shared.startNavigation()
                }) {
                    Text("Zazeni vodica")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                }
                Button(action: {
                    
                    TapCoordinator.shared.clearScene()
                }){
                    Text("Pocisti pot")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                }
                
                }

            }
        }
    }


// MARK: - ARView Container
struct ARViewContainer: UIViewRepresentable {
    @Binding var waypoints: [SIMD3<Float>]
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        
        // Enable LiDAR scene reconstruction if supported
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        arView.session.run(config)
        
        // Tap gesture to place waypoints
        let tapGesture = UITapGestureRecognizer(target: context.coordinator,
                                                action: #selector(context.coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        // Set ARView for TapCoordinator
        TapCoordinator.shared.arView = arView
        TapCoordinator.shared.waypoints = $waypoints
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            TapCoordinator.shared.handleTap(sender)
        }
    }
}

// MARK: - TapCoordinator Singleton
class TapCoordinator: NSObject {
    
    static let shared = TapCoordinator()
    
    weak var arView: ARView?
    var waypoints: Binding<[SIMD3<Float>]>?
    
    private var arrowAnchor: AnchorEntity?
    private var arrowEntity: ModelEntity?
    private var currentWaypointIndex = 0
    private var updateCancellable: Cancellable?
    
    func clearScene() {
        arView?.scene.anchors.removeAll()
        waypoints?.wrappedValue = []
        arrowAnchor = nil
        arrowEntity = nil
        currentWaypointIndex = 0
        print("AR scena in pot sta počisteni.")
    }

    
    // Handle screen taps
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        let location = sender.location(in: arView)
        
        // Use raycast to get estimated plane
        if let result = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal).first {
            var position = result.worldTransform.translation
            
            // Snap to floor using LiDAR mesh if available
            if let floorY = findFloorY(at: position) {
                position.y = floorY
            }
            
            addWaypoint(at: position)
        }
    }
    
    private func findFloorY(at position: SIMD3<Float>) -> Float? {
        guard let arView = arView,
              let frame = arView.session.currentFrame else { return nil }
        
        var closestY: Float? = nil
        
        for anchor in frame.anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
            let geometry = meshAnchor.geometry
            
            // Get vertex buffer pointer
            let vertexBuffer = geometry.vertices.buffer
            let vertexStride = geometry.vertices.stride
            let vertexCount = geometry.vertices.count
            
            for i in 0..<vertexCount {
                let vertexPtr = vertexBuffer.contents().advanced(by: i * vertexStride)
                
                // Each vertex is 3 floats: x, y, z
                let floatPtr = vertexPtr.bindMemory(to: Float.self, capacity: 3)
                let localPos = SIMD3<Float>(floatPtr[0], floatPtr[1], floatPtr[2])
                
                // Convert from local mesh space to world space
                let worldPos4 = meshAnchor.transform * SIMD4<Float>(localPos.x, localPos.y, localPos.z, 1)
                let worldPos = SIMD3<Float>(worldPos4.x, worldPos4.y, worldPos4.z)
                
                // Only consider vertices below the tap position
                if worldPos.y <= position.y {
                    if closestY == nil || abs(worldPos.y - position.y) < abs(closestY! - position.y) {
                        closestY = worldPos.y
                    }
                }
            }
        }
        
        return closestY
    }


    
    //MARK: - Dodamo tocko
    private func addWaypoint(at position: SIMD3<Float>) {
        guard let arView = arView else { return }
        
        let sphere = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.05),
                                 materials: [SimpleMaterial(color: .blue, isMetallic: false)])
        let anchor = AnchorEntity(world: position)
        anchor.addChild(sphere)
        arView.scene.addAnchor(anchor)
        
        waypoints?.wrappedValue.append(position)
        
        if let points = waypoints?.wrappedValue, points.count > 1 {
            drawLine(from: points[points.count - 2], to: points.last!)
        }
    }
    
    //MARK: - Narisemo pot med tockami
    private func drawLine(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        guard let arView = arView else { return }

        let vector = end - start
        let distance = simd_length(vector)
        let midPoint = start + vector / 2

        let cylinder = ModelEntity(mesh: MeshResource.generateCylinder(height: distance, radius: 0.01),
                                   materials: [SimpleMaterial(color: .yellow, isMetallic: false)])

        cylinder.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(vector))

        let anchor = AnchorEntity(world: midPoint)
        anchor.addChild(cylinder)
        arView.scene.addAnchor(anchor)
    }
    
    // MARK: - WIP puscica za navigacijo
    func startNavigation() {
        guard let arView = arView, let points = waypoints?.wrappedValue, points.count > 1 else { return }
        
        if arrowEntity == nil {
            let arrow = ModelEntity(mesh: MeshResource.generateCone(height: 0.1, radius: 0.05),
                                    materials: [SimpleMaterial(color: .red, isMetallic: false)])
            arrowEntity = arrow
            
            // Kje puscica zacne
            let first = points[0]
            let second = points[1]
            let direction = simd_normalize(second - first)
            arrow.position = first + direction * 0.3
            
            arrowAnchor = AnchorEntity(world: first)
            arrowAnchor!.addChild(arrow)
            arView.scene.addAnchor(arrowAnchor!)
        }
        
        currentWaypointIndex = 1
        
       
        updateCancellable = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            self?.updateArrowPosition()
        }
    }
    
    private func updateArrowPosition() {
        guard let arrow = arrowEntity,
              let points = waypoints?.wrappedValue,
              currentWaypointIndex < points.count - 1 else { return }

        let userPos = arView?.cameraTransform.translation ?? SIMD3<Float>(0,0,0)
        let prev = points[currentWaypointIndex]
        let next = points[currentWaypointIndex + 1]

        // Horizontal direction along segment
        let dir = simd_normalize(SIMD3(next.x - prev.x, 0, next.z - prev.z))
        let segmentLength = simd_length(SIMD2(next.x - prev.x, next.z - prev.z))
        
        if segmentLength == 0 { return }

        // Project user onto segment
        let projectedDistance = simd_dot(SIMD3(userPos.x - prev.x, 0, userPos.z - prev.z), dir)

        // Offset so arrow is slightly ahead
        let offset: Float = 0.4
        var clampedDistance = projectedDistance + offset

        // Handle segment completion smoothly
        if clampedDistance > segmentLength {
            let overflow = clampedDistance - segmentLength
            if currentWaypointIndex < points.count - 2 {
                currentWaypointIndex += 1
                let nextPrev = points[currentWaypointIndex]
                let nextNext = points[currentWaypointIndex + 1]
                let nextDir = simd_normalize(SIMD3(nextNext.x - nextPrev.x, 0, nextNext.z - nextPrev.z))
                let nextLength = simd_length(SIMD2(nextNext.x - nextPrev.x, nextNext.z - nextPrev.z))
                clampedDistance = min(overflow, nextLength)
                arrow.position = SIMD3(
                    nextPrev.x + nextDir.x * clampedDistance,
                    userPos.y,
                    nextPrev.z + nextDir.z * clampedDistance
                )
                arrow.look(at: nextNext, from: arrow.position, relativeTo: nil)
                return
            } else {
                // Last segment reached
                clampedDistance = segmentLength
            }
        }

        // Arrow position along current segment
        arrow.position = SIMD3(
            prev.x + dir.x * clampedDistance,
            userPos.y - 0.3,
            prev.z + dir.z * clampedDistance
        )
        
        // Rotate toward next waypoint
        arrow.look(at: next, from: arrow.position, relativeTo: nil)
    }

}

// MARK: - Helper
extension simd_float4x4 {
    var translation: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}



