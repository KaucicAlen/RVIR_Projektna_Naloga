//
//  ARViewContainer.swift
//  ARTest
//
//  Created by Alen Kaucic on 16. 01. 26.
//

import ARKit
import RealityKit
import SwiftUI

struct ARViewContainer: UIViewControllerRepresentable {
    var mode: ARMode = .scanning
    var worldMapData: WorldMapData?
    var onMapSaved: ((ARWorldMap) -> Void)?
    var onClassroomPositionSelected: ((SIMD3<Float>) -> Void)?
    
    func makeUIViewController(context: Context) -> ARViewController {
        let controller = ARViewController()
        controller.arMode = mode
        controller.worldMapData = worldMapData
        controller.onMapSaved = onMapSaved
        controller.onClassroomPositionSelected = onClassroomPositionSelected
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        uiViewController.arMode = mode
        uiViewController.worldMapData = worldMapData
    }
}

enum ARMode {
    case scanning
    case viewing
    case placing
}

class ARViewController: UIViewController, ARSessionDelegate {
    var arView: ARView!
    var arSession: ARSession {
        return arView.session
    }
    
    var arMode: ARMode = .scanning
    var worldMapData: WorldMapData?
    var onMapSaved: ((ARWorldMap) -> Void)?
    var onClassroomPositionSelected: ((SIMD3<Float>) -> Void)?
    
    private var statusLabel: UILabel!
    private var actionButton: UIButton!
    private var mapFrameAnchor: ModelEntity?
    private var syncIndicator: UIActivityIndicatorView!
    private var syncLabel: UILabel!
    private var isSynced = false
    private var syncCheckTimer: Timer?
    private var updateVisibilityTimer: Timer?
    private var navigationUpdateTimer: Timer?
    private var classroomAnchors: [UUID: AnchorEntity] = [:]
    private var visibilityCountLabel: UILabel!
    private var navigationGuideAnchor: AnchorEntity?
    private var selectedClassroomId: UUID?
    private var classroomSelectButton: UIButton!
    private var placementPreviewAnchor: AnchorEntity?
    private var waypointAnchors: [AnchorEntity] = []
    private var currentWaypoints: [SIMD3<Float>] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize ARView with proper frame
        arView = ARView(frame: view.bounds)
        arView.session.delegate = self
        view.addSubview(arView)
        
        // Add UI elements
        setupUI()
        
        // Configure AR based on mode
        configureARSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startARSession()
        
        // Start sync check timer if in viewing mode
        if arMode == .viewing {
            syncCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.checkSyncStatus()
            }
            
            // Start visibility update timer to hide occluded classrooms
            updateVisibilityTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateClassroomVisibility()
            }
            
            // Start navigation guide update timer
            navigationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                self?.updateNavigationGuide()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseARSession()
        
        // Stop sync check timer
        syncCheckTimer?.invalidate()
        syncCheckTimer = nil
        
        // Stop visibility update timer
        updateVisibilityTimer?.invalidate()
        updateVisibilityTimer = nil
        
        // Stop navigation timer
        navigationUpdateTimer?.invalidate()
        navigationUpdateTimer = nil
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Helper function to create glass-morphism background
        func createGlassBackground() -> UIView {
            let container = UIView()
            container.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            container.layer.cornerRadius = 12
            container.layer.borderWidth = 1
            container.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
            container.clipsToBounds = true
            
            // Add blur effect
            let blur = UIBlurEffect(style: .dark)
            let blurView = UIVisualEffectView(effect: blur)
            blurView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(blurView)
            container.sendSubviewToBack(blurView)
            
            NSLayoutConstraint.activate([
                blurView.topAnchor.constraint(equalTo: container.topAnchor),
                blurView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                blurView.leftAnchor.constraint(equalTo: container.leftAnchor),
                blurView.rightAnchor.constraint(equalTo: container.rightAnchor)
            ])
            
            return container
        }
        
        // Top Status Bar Container
        let topContainer = createGlassBackground()
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topContainer)
        
        NSLayoutConstraint.activate([
            topContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            topContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topContainer.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.85),
            topContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
        
        // Status Label
        statusLabel = UILabel()
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.numberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        topContainer.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: topContainer.topAnchor, constant: 12),
            statusLabel.bottomAnchor.constraint(equalTo: topContainer.bottomAnchor, constant: -12),
            statusLabel.centerXAnchor.constraint(equalTo: topContainer.centerXAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: topContainer.widthAnchor, constant: -16)
        ])
        
        // Visibility Counter (Top Right)
        let visContainer = createGlassBackground()
        visContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(visContainer)
        
        NSLayoutConstraint.activate([
            visContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            visContainer.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -12),
            visContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            visContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        
        visibilityCountLabel = UILabel()
        visibilityCountLabel.textColor = UIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1.0) // Bright green
        visibilityCountLabel.textAlignment = .center
        visibilityCountLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        visibilityCountLabel.translatesAutoresizingMaskIntoConstraints = false
        visContainer.addSubview(visibilityCountLabel)
        
        NSLayoutConstraint.activate([
            visibilityCountLabel.topAnchor.constraint(equalTo: visContainer.topAnchor, constant: 8),
            visibilityCountLabel.bottomAnchor.constraint(equalTo: visContainer.bottomAnchor, constant: -8),
            visibilityCountLabel.centerXAnchor.constraint(equalTo: visContainer.centerXAnchor),
            visibilityCountLabel.widthAnchor.constraint(lessThanOrEqualTo: visContainer.widthAnchor, constant: -12)
        ])
        
        if arMode != .viewing {
            visContainer.isHidden = true
        }
        
        // Navigation Button (Second row, left side)
        let navContainer = createGlassBackground()
        navContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navContainer)
        
        NSLayoutConstraint.activate([
            navContainer.topAnchor.constraint(equalTo: topContainer.bottomAnchor, constant: 12),
            navContainer.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 12),
            navContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        
        classroomSelectButton = UIButton(type: .system)
        classroomSelectButton.setTitleColor(.white, for: .normal)
        classroomSelectButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        classroomSelectButton.translatesAutoresizingMaskIntoConstraints = false
        navContainer.addSubview(classroomSelectButton)
        
        NSLayoutConstraint.activate([
            classroomSelectButton.topAnchor.constraint(equalTo: navContainer.topAnchor, constant: 8),
            classroomSelectButton.bottomAnchor.constraint(equalTo: navContainer.bottomAnchor, constant: -8),
            classroomSelectButton.leftAnchor.constraint(equalTo: navContainer.leftAnchor, constant: 12),
            classroomSelectButton.rightAnchor.constraint(equalTo: navContainer.rightAnchor, constant: -12)
        ])
        
        classroomSelectButton.setTitle("🧭 Navigate", for: .normal)
        classroomSelectButton.addTarget(self, action: #selector(selectClassroomTapped), for: .touchUpInside)
        
        if arMode != .viewing {
            navContainer.isHidden = true
        }
        
        // Sync Indicator (Center)
        let syncContainer = createGlassBackground()
        syncContainer.translatesAutoresizingMaskIntoConstraints = false
        syncContainer.tag = 9999
        view.addSubview(syncContainer)
        
        NSLayoutConstraint.activate([
            syncContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            syncContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            syncContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            syncContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
        
        // Mapp sync indicator
        syncIndicator = UIActivityIndicatorView(style: .large)
        syncIndicator.color = UIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1.0)
        syncIndicator.translatesAutoresizingMaskIntoConstraints = false
        syncIndicator.tag = 9998
        syncContainer.addSubview(syncIndicator)
        
        NSLayoutConstraint.activate([
            syncIndicator.centerXAnchor.constraint(equalTo: syncContainer.centerXAnchor),
            syncIndicator.topAnchor.constraint(equalTo: syncContainer.topAnchor, constant: 16)
        ])
        
        // Sync Label
        syncLabel = UILabel()
        syncLabel.text = "Syncing map..."
        syncLabel.textColor = .white
        syncLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        syncLabel.textAlignment = .center
        syncLabel.translatesAutoresizingMaskIntoConstraints = false
        syncLabel.tag = 9997
        syncContainer.addSubview(syncLabel)
        
        NSLayoutConstraint.activate([
            syncLabel.centerXAnchor.constraint(equalTo: syncContainer.centerXAnchor),
            syncLabel.topAnchor.constraint(equalTo: syncIndicator.bottomAnchor, constant: 16),
            syncLabel.bottomAnchor.constraint(equalTo: syncContainer.bottomAnchor, constant: -16),
            syncLabel.widthAnchor.constraint(lessThanOrEqualTo: syncContainer.widthAnchor, constant: -16)
        ])
        
        if arMode != .viewing {
            syncIndicator.isHidden = true
            syncLabel.isHidden = true
            syncContainer.isHidden = true
        } else {
            syncIndicator.startAnimating()
        }
        
        // Bottom Action Button
        let bottomContainer = createGlassBackground()
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomContainer)
        
        NSLayoutConstraint.activate([
            bottomContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            bottomContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            bottomContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
        
        actionButton = UIButton(type: .system)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.addSubview(actionButton)
        
        NSLayoutConstraint.activate([
            actionButton.topAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: 10),
            actionButton.bottomAnchor.constraint(equalTo: bottomContainer.bottomAnchor, constant: -10),
            actionButton.leftAnchor.constraint(equalTo: bottomContainer.leftAnchor, constant: 16),
            actionButton.rightAnchor.constraint(equalTo: bottomContainer.rightAnchor, constant: -16)
        ])
        
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        updateButtonForMode()
    }
    
    private func updateButtonForMode() {
        switch arMode {
        case .scanning:
            actionButton.setTitle("Save Map", for: .normal)
        case .viewing:
            actionButton.setTitle("Done", for: .normal)
        case .placing:
            actionButton.setTitle("Place Classroom", for: .normal)
        }
    }
    
    // MARK: - AR Configuration
    private func configureARSession() {
        let configuration = ARWorldTrackingConfiguration()
        
        // Check device support
        guard ARWorldTrackingConfiguration.isSupported else {
            statusLabel.text = "ARKit not supported"
            return
        }
        
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        // Only enable segmentation if supported
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        // Load map if viewing/placing
        if let worldMapData = worldMapData, arMode != .scanning {
            do {
                let worldMap = try MapStorageManager.shared.loadWorldMap(with: worldMapData.id)
                configuration.initialWorldMap = worldMap
            } catch {
                print("Error loading world map: \(error)")
                statusLabel.text = "Failed to load map"
            }
        }
        
        // Run the session
        DispatchQueue.main.async {
            self.arView.session.run(configuration)
        }
    }
    
    private func startARSession() {
        // Check if already running
        if arView.session.configuration != nil {
            return
        }
        
        let configuration = ARWorldTrackingConfiguration()
        guard ARWorldTrackingConfiguration.isSupported else {
            statusLabel.text = "ARKit not supported"
            return
        }
        
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        // Load map if viewing/placing
        if let worldMapData = worldMapData, arMode != .scanning {
            do {
                let worldMap = try MapStorageManager.shared.loadWorldMap(with: worldMapData.id)
                configuration.initialWorldMap = worldMap
            } catch {
                print("Error loading world map: \(error)")
                statusLabel.text = "Failed to load map"
                return
            }
        }
        
        DispatchQueue.main.async {
            self.arView.session.run(configuration)
            self.updateStatusLabel()
            
            // Display classrooms if in viewing mode
            if self.arMode == .viewing, let worldMapData = self.worldMapData {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.displayClassrooms(worldMapData.classrooms)
                }
            }
        }
    }
    
    private func pauseARSession() {
        arView.session.pause()
    }
    
    // MARK: - Actions
    @objc private func actionButtonTapped() {
        switch arMode {
        case .scanning:
            saveCurrentMap()
        case .viewing:
            dismiss(animated: true)
        case .placing:
            placeClassroomAtCenter()
        }
    }
    
    @objc private func selectClassroomTapped() {
        guard let worldMapData = worldMapData else { return }
        
        let classrooms = worldMapData.classrooms
        guard !classrooms.isEmpty else { return }
        
        // Create action sheet with classroom options
        let alert = UIAlertController(title: "Navigate to Classroom", message: "Select a classroom to navigate to", preferredStyle: .actionSheet)
        
        for classroom in classrooms {
            alert.addAction(UIAlertAction(title: classroom.name, style: .default) { _ in
                self.selectedClassroomId = classroom.id
                // Generate waypoints to the selected classroom
                if let classroomPos = worldMapData.classrooms.first(where: { $0.id == classroom.id })?.position.toSIMD3() {
                    if let currentFrame = self.arView.session.currentFrame {
                        let currentPos = SIMD3<Float>(
                            currentFrame.camera.transform.columns.3.x,
                            currentFrame.camera.transform.columns.3.y,
                            currentFrame.camera.transform.columns.3.z
                        )
                        self.generateWaypoints(from: currentPos, to: classroomPos)
                    }
                }
            })
        }
        
        // Add clear selection option
        alert.addAction(UIAlertAction(title: "Clear Navigation", style: .destructive) { _ in
            self.selectedClassroomId = nil
            self.removeNavigationGuide()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        self.present(alert, animated: true)
    }
    
    private func saveCurrentMap() {
        arView.session.getCurrentWorldMap { worldMap, error in
            guard let worldMap = worldMap else {
                print("Error getting world map: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.statusLabel.text = "Failed to save map"
                }
                return
            }
            
            // Show alert to name the map
            DispatchQueue.main.async {
                self.showMapNameAlert(for: worldMap)
            }
        }
    }
    
    private func showMapNameAlert(for worldMap: ARWorldMap) {
        let alert = UIAlertController(title: "Save New Map", message: "Enter a name for this building map:", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Building name"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.statusLabel.text = "Map save cancelled"
        })
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let name = alert.textFields?.first?.text, !name.isEmpty {
                do {
                    let mapData = try MapStorageManager.shared.saveWorldMap(worldMap, with: name)
                    self.statusLabel.text = "Map '\(name)' saved!"
                    
                    // Call the callback with the saved data
                    self.onMapSaved?(worldMap)
                    
                    // Dismiss after a short delay to show the success message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.dismiss(animated: true)
                    }
                } catch {
                    self.statusLabel.text = "Failed to save: \(error.localizedDescription)"
                    print("Error saving map: \(error)")
                }
            } else {
                self.statusLabel.text = "Please enter a map name"
            }
        })
        
        self.present(alert, animated: true)
    }
    
    private func placeClassroomAtCenter() {
        
        if let frame = arView.session.currentFrame {
            let cameraTransform = frame.camera.transform
            
            // Place classroom
            let centerPosition = SIMD3<Float>(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y - 0.3,
                cameraTransform.columns.3.z - 1.0
            )
            
            onClassroomPositionSelected?(centerPosition)
            DispatchQueue.main.async {
                self.dismiss(animated: true)
            }
        } else {
            statusLabel.text = "Tracking not ready"
        }
    }
    
    // MARK: - Display Classrooms
    func displayClassrooms(_ classrooms: [Classroom]) {
        var anchorsToRemove: [AnchorEntity] = []
        for anchor in arView.scene.anchors {
            if let anchorEntity = anchor as? AnchorEntity {
                anchorsToRemove.append(anchorEntity)
            }
        }
        for anchor in anchorsToRemove {
            arView.scene.removeAnchor(anchor)
        }
        
        classroomAnchors.removeAll()
        
        for (index, classroom) in classrooms.enumerated() {
            let position = classroom.position.toSIMD3()
            let anchor = addClassroomAnchor(classroom: classroom, position: position, index: index, totalCount: classrooms.count)
            classroomAnchors[classroom.id] = anchor
        }
    }
    
    private func addClassroomAnchor(classroom: Classroom, position: SIMD3<Float>, index: Int, totalCount: Int) -> AnchorEntity {
        let anchor = AnchorEntity(plane: .horizontal)
        
       
        let offsetRadius: Float = 0.25
        let angle = Float(index) * (2.0 * Float.pi / Float(totalCount))
        let offsetX = offsetRadius * cos(angle)
        let offsetZ = offsetRadius * sin(angle)
        
        let offsetPosition = SIMD3<Float>(
            position.x + offsetX,
            position.y,
            position.z + offsetZ
        )
        
        anchor.move(to: Transform(translation: offsetPosition), relativeTo: anchor, duration: 0, timingFunction: .linear)
        
        let mesh = MeshResource.generateBox(size: 0.2)
        
        let color = colorForClassroom(classroom)
        let uiColor = UIColor(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: CGFloat(color.w))
        
        var material = SimpleMaterial()
        material.color = .init(tint: uiColor)
        
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        anchor.addChild(modelEntity)
        
        // Add text label above the classroom
        addTextLabel(to: anchor, text: classroom.name, offset: SIMD3<Float>(0, 0.15, 0))
        
        arView.scene.addAnchor(anchor)
        
        return anchor
    }
    
    private func addTextLabel(to anchor: AnchorEntity, text: String, offset: SIMD3<Float>) {

        anchor.name = text
    }
    
    private func colorForClassroom(_ classroom: Classroom) -> SIMD4<Float> {
        
        let hash = UInt(classroom.id.uuid.0) ^ UInt(classroom.id.uuid.1)
        let hue = Float(hash % 360) / 360.0
        
        let rgb = hsvToRGB(hue: hue, saturation: 0.7, value: 0.9)
        return SIMD4<Float>(rgb.0, rgb.1, rgb.2, 1.0)
    }
    
    private func hsvToRGB(hue: Float, saturation: Float, value: Float) -> (Float, Float, Float) {
        let c = value * saturation
        let h = hue * 6
        let x = c * (1 - abs((h.truncatingRemainder(dividingBy: 2)) - 1))
        
        var rgb: (Float, Float, Float) = (0, 0, 0)
        
        if h < 1 {
            rgb = (c, x, 0)
        } else if h < 2 {
            rgb = (x, c, 0)
        } else if h < 3 {
            rgb = (0, c, x)
        } else if h < 4 {
            rgb = (0, x, c)
        } else if h < 5 {
            rgb = (x, 0, c)
        } else {
            rgb = (c, 0, x)
        }
        
        let m = value - c
        return (rgb.0 + m, rgb.1 + m, rgb.2 + m)
    }
    
    // MARK: - Status Updates
    private func updateStatusLabel() {
        DispatchQueue.main.async {
            switch self.arMode {
            case .scanning:
                self.statusLabel.text = "Move around to scan\nthe environment"
            case .viewing:
                self.statusLabel.text = "Viewing saved map"
            case .placing:
                self.statusLabel.text = "Position at center\nof screen and tap Place"
            }
        }
    }
    
    private func checkSyncStatus() {
        guard arMode == .viewing else { return }
        
        DispatchQueue.main.async {
            // Check if AR session has good tracking
            if let frame = self.arView.session.currentFrame {
                let trackingState = frame.camera.trackingState
                
                switch trackingState {
                case .normal:
                    // Map is synced and tracking well
                    if !self.isSynced {
                        self.isSynced = true
                        UIView.animate(withDuration: 0.5, animations: {
                            self.syncIndicator.alpha = 0
                            self.syncLabel.alpha = 0
                        }) { _ in
                            self.syncIndicator.stopAnimating()
                            self.syncIndicator.isHidden = true
                            self.syncLabel.isHidden = true
                            if let syncContainer = self.view.viewWithTag(9999) {
                                syncContainer.isHidden = true
                            }
                        }
                    }
                case .limited(_):
                    // Still syncing
                    if self.isSynced {
                        self.isSynced = false
                        self.syncIndicator.isHidden = false
                        self.syncLabel.isHidden = false
                        self.syncIndicator.alpha = 1
                        self.syncLabel.alpha = 1
                        if let syncContainer = self.view.viewWithTag(9999) {
                            syncContainer.isHidden = false
                        }
                        self.syncIndicator.startAnimating()
                    }
                case .notAvailable:
                    self.syncLabel.text = "Tracking unavailable"
                    if self.syncIndicator.isAnimating {
                        self.syncIndicator.stopAnimating()
                    }
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - Occlusion Culling (Hide blocked classrooms)
    private func updateClassroomVisibility() {
        guard arMode == .viewing, let frame = arView.session.currentFrame else { return }
        
        let cameraPosition = SIMD3<Float>(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )
        
        // Get camera forward direction
        let cameraForward = SIMD3<Float>(
            -frame.camera.transform.columns.2.x,
            -frame.camera.transform.columns.2.y,
            -frame.camera.transform.columns.2.z
        )
        
        var visibleCount = 0
        
        for (classroomId, anchor) in classroomAnchors {
            // Get classroom position
            let classroomPosition = anchor.transform.translation
            
            // Vector from camera to classroom
            let toClassroom = classroomPosition - cameraPosition
            let distance = length(toClassroom)
            
            // Check if classroom is in front of camera
            let directionToClassroom = normalize(toClassroom)
            let dotProduct = dot(cameraForward, directionToClassroom)
            
            // Show classroom only
            let isInFront = dotProduct > 0.1
            let isInRange = distance < 50.0
            let shouldBeVisible = isInFront && isInRange
            
            // Update visibility
            for child in anchor.children {
                if child.isEnabled != shouldBeVisible {
                    child.isEnabled = shouldBeVisible
                }
            }
            
          
            if shouldBeVisible {
                visibleCount += 1
            }
        }
        
        // Update visibility counter
        DispatchQueue.main.async {
            let totalCount = self.classroomAnchors.count
            self.visibilityCountLabel.text = "Visible: \(visibleCount)/\(totalCount)"
        }
    }
    
    // MARK: - Navigation Guide (Waypoint-based pathfinding)
    private func updateNavigationGuide() {
        guard arMode == .viewing, selectedClassroomId != nil else {
            removeNavigationGuide()
            return
        }
        
        // Update waypoint
        if let frame = arView.session.currentFrame {
            let cameraPosition = SIMD3<Float>(
                frame.camera.transform.columns.3.x,
                frame.camera.transform.columns.3.y,
                frame.camera.transform.columns.3.z
            )
            
            let cameraForward = SIMD3<Float>(
                -frame.camera.transform.columns.2.x,
                -frame.camera.transform.columns.2.y,
                -frame.camera.transform.columns.2.z
            )
            
            // Update each waypoint
            for (index, waypointAnchor) in waypointAnchors.enumerated() {
                let waypointPos = waypointAnchor.transform.translation
                let toWaypoint = waypointPos - cameraPosition
                let distance = length(toWaypoint)
                
                let directionToWaypoint = normalize(toWaypoint)
                let dotProduct = dot(cameraForward, directionToWaypoint)
                
    
                let isInFront = dotProduct > 0.1
                let isInRange = distance < 50.0
                let shouldBeVisible = isInFront && isInRange
                
                for child in waypointAnchor.children {
                    child.isEnabled = shouldBeVisible
                }
                
                // Highlight the next waypoint
                if index < waypointAnchors.count - 1 && shouldBeVisible {
    
                    for child in waypointAnchor.children {
                        if let modelEntity = child as? ModelEntity {
                            var material = SimpleMaterial()
                            material.color = .init(tint: UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))
                            modelEntity.model?.materials = [material]
                        }
                    }
                } else if index == waypointAnchors.count - 1 {
                    for child in waypointAnchor.children {
                        if let modelEntity = child as? ModelEntity {
                            var material = SimpleMaterial()
                            material.color = .init(tint: UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0))
                            modelEntity.model?.materials = [material]
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Waypoint Generation
    private func generateWaypoints(from start: SIMD3<Float>, to destination: SIMD3<Float>) {
        // Remove old waypoints
        removeNavigationGuide()
        currentWaypoints.removeAll()
        waypointAnchors.removeAll()
        
        DispatchQueue.main.async {
            self.statusLabel.text = "Calculating path..."
        }
        
        // Call API
        PathfindingManager.shared.getPath(
            from: (x: start.x, z: start.z),
            to: (x: destination.x, z: destination.z)
        ) { [weak self] waypoints, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Pathfinding error: \(error.localizedDescription)")
                    self?.statusLabel.text = "Path calculation failed"
                    self?.displayFallbackWaypoints(from: start, to: destination)
                    return
                }
                
                guard let waypoints = waypoints, !waypoints.isEmpty else {
                    print("No waypoints received")
                    self?.statusLabel.text = "No path found"
                    self?.displayFallbackWaypoints(from: start, to: destination)
                    return
                }
                
                self?.currentWaypoints = waypoints
                self?.displayWaypoints(waypoints)
                self?.statusLabel.text = "Path created - \(waypoints.count) waypoints"
                print("Navigation path created with \(waypoints.count) waypoints from server")
            }
        }
    }
    
    private func displayFallbackWaypoints(from start: SIMD3<Float>, to destination: SIMD3<Float>) {
        let distance = length(destination - start)
        let direction = normalize(destination - start)
        
        let waypointInterval: Float = 0.5
        let numWaypoints = Int(distance / waypointInterval)
        
        var waypoints: [SIMD3<Float>] = []
        
        for i in 0..<numWaypoints {
            let progress = Float(i + 1) * waypointInterval
            let waypoint = start + (direction * progress)
            waypoints.append(waypoint)
        }
        
        waypoints.append(destination)
        
        currentWaypoints = waypoints
        displayWaypoints(waypoints)
        print("Using fallback linear path with \(waypoints.count) waypoints")
    }
    
    private func generateHardcodedWaypoints(from start: SIMD3<Float>, to destination: SIMD3<Float>) -> [SIMD3<Float>] {
        
        // OLD!!!!
        
        let distance = length(destination - start)
        let direction = normalize(destination - start)
        
        let waypointInterval: Float = 0.5
        let numWaypoints = Int(distance / waypointInterval)
        
        var waypoints: [SIMD3<Float>] = []
        
        for i in 0..<numWaypoints {
            let progress = Float(i + 1) * waypointInterval
            let waypoint = start + (direction * progress)
            waypoints.append(waypoint)
        }
        
        waypoints.append(destination)
        
        return waypoints
    }
    
    private func displayWaypoints(_ waypoints: [SIMD3<Float>]) {
        for (index, position) in waypoints.enumerated() {
            let anchor = AnchorEntity(plane: .horizontal)
            anchor.move(to: Transform(translation: position), relativeTo: anchor, duration: 0, timingFunction: .linear)
            
            // Create sphere for waypoint
            let mesh = MeshResource.generateSphere(radius: 0.08)
            
            
            let color: UIColor = index == waypoints.count - 1 ?
                UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0) :
                UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
            
            var material = SimpleMaterial()
            material.color = .init(tint: color)
            
            let waypointModel = ModelEntity(mesh: mesh, materials: [material])
            anchor.addChild(waypointModel)
            
            if index < waypoints.count - 1 {
                let nextPos = waypoints[index + 1]
                addWaypointConnection(from: position, to: nextPos, to: anchor)
            }
            
            arView.scene.addAnchor(anchor)
            waypointAnchors.append(anchor)
        }
    }
    
    private func addWaypointConnection(from: SIMD3<Float>, to: SIMD3<Float>, to anchor: AnchorEntity) {
        let direction = to - from
        let distance = length(direction)
        
        if distance > 0.01 {
            let mesh = MeshResource.generateCylinder(height: distance, radius: 0.02)
            
            var material = SimpleMaterial()
            material.color = .init(tint: UIColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.6))
            
            let lineModel = ModelEntity(mesh: mesh, materials: [material])
            
            
            let midpoint = (from + to) * 0.5
            let normalizedDir = normalize(direction)
            
            anchor.addChild(lineModel)
        }
    }
    
    private func removeNavigationGuide() {
        for anchor in waypointAnchors {
            arView.scene.removeAnchor(anchor)
        }
        waypointAnchors.removeAll()
        currentWaypoints.removeAll()
    }
    
    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session error: \(error)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        statusLabel.text = "AR Session interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        statusLabel.text = "Resuming AR session"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.updateStatusLabel()
        }
    }
}
