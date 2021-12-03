/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import UIKit
import SceneKit
import ARKit
import FirebaseStorage
import simd

class ARPathCreatorViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    // MARK: - IBOutlets
    
    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var takeImageButton: RoundedButton!
    @IBOutlet weak var takeDestinationImageButton: RoundedButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var snapshotThumbnail: UIImageView!
    @IBOutlet weak var succesCheckmark: UIImageView!
    
//    var pathId: String?
    var worldMap: ARWorldMap?
    var isCreatingPath: Bool = true
    var isLoadingData: Bool = true
    var startPointSnapshotAnchor: SnapshotAnchor?
    var destinationSnapshotAnchor: SnapshotAnchor?
    
    var delegate: ARPathCreatorViewControllerDelegate?
    
    // MARK: - View Life Cycle
    
    // Lock the orientation of the app to the orientation in which it is launched
    override var shouldAutorotate: Bool {
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        succesCheckmark.isHidden = true
        
        if !isCreatingPath {
            self.loadExperience()
            self.saveButton.isHidden = true
            self.takeImageButton.isHidden = true
            self.takeDestinationImageButton.isHidden = true
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If theho app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }
        
        // Start the view's AR session.
        sceneView.session.delegate = self
        sceneView.session.run(defaultConfiguration)
        sceneView.debugOptions = [ .showFeaturePoints ]
        sceneView.autoenablesDefaultLighting = true
        
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's AR session.
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    func generateFlatDisk() -> SCNNode {
        let disk = SCNCylinder(radius: 0.001, height: 0.001);
        let diskNode = SCNNode()
        diskNode.geometry = disk
        disk.firstMaterial?.diffuse.contents = UIColor(red: 234/255, green: 58/255, blue: 186/255, alpha: 1.00)
//        disk.firstMaterial?.lightingModel = .lambert
//        disk.firstMaterial?.transparency = 0.80
//        disk.firstMaterial?.transparencyMode = .dualLayer
//        disk.firstMaterial?.fresnelExponent = 0.80
//        disk.firstMaterial?.reflective.contents = UIColor(white:0.00, alpha:1.0)
//        disk.firstMaterial?.specular.contents = UIColor(white:0.00, alpha:1.0)
//        disk.firstMaterial?.shininess = 0.80
        return diskNode
    }

    func generateText(_ text: String, font: UIFont? = UIFont(name: "LyftProUI-Medium", size: 16)) -> SCNNode {
        let text = SCNText(string: text, extrusionDepth: 2)
        text.font = font
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white

        text.materials = [material]
        let node = SCNNode(geometry: text)
        node.scale = SCNVector3(0.015, 0.015, 0.015)
        node.eulerAngles.x = -Float.pi / 4
        
        return node
    }

    var nodesStack = Stack<(point: SCNNode, line: SCNNode?)>()

    /// - Tag: RestoreVirtualContent
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor.name == virtualObjectAnchorName
            else { return }

        DispatchQueue.main.async {
            var lineNode: SCNNode?
            if let previousNode = self.nodesStack.top?.point {
                lineNode = self.cylinderLine(from: previousNode.position, to: node.position)
                self.sceneView.scene.rootNode.addChildNode(lineNode!)
            } else {
                let text = self.generateText("Exit T4")
                text.position.x -= 0.25
                node.addChildNode(text)
            }
            self.nodesStack.push((point: node, line: lineNode))
        }
    }

    func cylinderLine(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let x1 = from.x
        let x2 = to.x

        let y1 = from.y
        let y2 = to.y

        let z1 = from.z
        let z2 = to.z

        let distance = sqrtf((x2 - x1) * (x2 - x1) +
                             (y2 - y1) * (y2 - y1) +
                             (z2 - z1) * (z2 - z1))

        let cylinder = SCNCapsule(capRadius: 0.05, height: CGFloat(distance))

        cylinder.firstMaterial?.diffuse.contents = UIColor.yellow

        cylinder.firstMaterial?.diffuse.contents = UIColor(red: 234/255, green: 58/255, blue: 186/255, alpha: 1.00)
        cylinder.firstMaterial?.lightingModel = .lambert
        cylinder.firstMaterial?.transparencyMode = .dualLayer
        cylinder.firstMaterial?.fresnelExponent = 0.80
        cylinder.firstMaterial?.reflective.contents = UIColor(white:0.00, alpha:1.0)
        cylinder.firstMaterial?.specular.contents = UIColor(white:0.00, alpha:1.0)
        cylinder.firstMaterial?.shininess = 0.80

        let lineNode = SCNNode(geometry: cylinder)
        lineNode.position = SCNVector3(((from.x + to.x)/2),
                                       ((from.y + to.y)/2),
                                       ((from.z + to.z)/2))

        lineNode.eulerAngles = SCNVector3(Float.pi/2,
                                          acos((to.z - from.z)/distance),
                                          atan2(to.y - from.y, to.x - from.x))

        lineNode.scale.z = 0.0001
        
        lineNode.name = "Path"

        return lineNode
    }

    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    /// - Tag: CheckMappingStatus
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Enable Save button only when the mapping status is good and an object has been placed
        switch frame.worldMappingStatus {
            case .extending, .mapped:
                saveButton.isEnabled =
                    virtualObjectAnchor != nil
                        && frame.anchors.contains(virtualObjectAnchor!)
                        && self.startPointSnapshotAnchor != nil
                        && self.destinationSnapshotAnchor != nil
            default:
                saveButton.isEnabled = false
        }
        statusLabel.text = """
            Mapping: \(frame.worldMappingStatus.description)
            Tracking: \(frame.camera.trackingState.description)
            """
        for anchor in frame.anchors {
            if (anchor.name == self.virtualObjectAnchorName) {
                let distance = simd_distance(anchor.transform.columns.3, (sceneView.session.currentFrame?.camera.transform.columns.3)!);
                let arNode = sceneView.node(for: anchor)
                // display only disks that are within three meters of the viewer
                if (distance < 3) {
                    arNode?.isHidden = false
                } else {
                    arNode?.isHidden = true
                }
            }
        }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    // MARK: - ARSessionObserver
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay.
        sessionInfoLabel.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required.
        sessionInfoLabel.text = "Session interruption ended"
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetTracking(nil)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
    
    // MARK: - Persistence: Saving and Loading
    lazy var mapSaveURL: URL = {
        do {
            return try FileManager.default
                .url(for: .documentDirectory,
                     in: .userDomainMask,
                     appropriateFor: nil,
                     create: true)
                .appendingPathComponent("map.arexperience")
        } catch {
            fatalError("Can't get file save URL: \(error.localizedDescription)")
        }
    }()
    
    @IBAction func onUndoButtonPress(_ sender: UIButton) {
        if let lastNode = nodesStack.pop() {

            lastNode.point.removeFromParentNode()
            lastNode.line?.removeFromParentNode()
        }
    }

    @IBAction func onBackButtonPress(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onStartPointImagePress(_ sender: Any) {
        // Add a snapshot image indicating where the map was captured.
        guard let snapshotAnchor = SnapshotAnchor(capturing: self.sceneView)
            else { fatalError("Can't take snapshot") }
        self.startPointSnapshotAnchor = snapshotAnchor
        self.succesCheckmark.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.succesCheckmark.isHidden = true
        }
    }

    @IBAction func onDestinationImagePress(_ sender: UIButton) {
        guard let lastNode = nodesStack.top?.point else { return }

        let whiteDisk = generateFlatDisk()
        whiteDisk.scale = SCNVector3(x: 250, y: 1, z: 250)
        whiteDisk.geometry?.materials.first?.diffuse.contents = UIColor.white
        whiteDisk.position.y += 0.0001

        let disk = generateFlatDisk()
        disk.scale = SCNVector3(x: 200, y: 1, z: 200)
        disk.position.y += 0.0002

        let finishText = generateText("Lyft", font: UIFont(name: "LyftProUI-Bolditalic", size: 16)!)
        finishText.position.x = -0.17

        lastNode.addChildNode(finishText)
        lastNode.addChildNode(whiteDisk)
        lastNode.addChildNode(disk)

        guard let snapshotAnchor = SnapshotAnchor(capturing: self.sceneView)
            else { fatalError("Can't take snapshot") }
        self.destinationSnapshotAnchor = snapshotAnchor
        self.succesCheckmark.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.succesCheckmark.isHidden = true
        }
    }
    
    /// - Tag: GetWorldMap
    @IBAction func saveExperience(_ button: UIButton) {
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { self.showAlert(title: "Can't get current world map", message: error!.localizedDescription); return }
            
            // Add a snapshot image indicating where the map was captured.

            let some = self.startPointSnapshotAnchor!

            map.anchors.append(some)

            do {
                Storage.endImage = self.destinationSnapshotAnchor
                Storage.startImage = self.startPointSnapshotAnchor
                Storage.worldData = map
                self.delegate?.completedARWorldMapCreation(
                    worldMapData: map,
                    startImage: self.startPointSnapshotAnchor!.imageData,
                    endImage: self.destinationSnapshotAnchor!.imageData
                )
            } catch {
                fatalError("Can't save map: \(error.localizedDescription)")
            }
        }
    }
    
    func loadExperience() {
        guard let world = worldMap else {
            return
        }

//        guard self.pathId != nil else {
//            return
//        }
//        let storage = Storage.storage()
//        let mapRefrence = storage.reference(withPath: "worldMaps/\(self.pathId ?? "")")
//        // 100 MB max
//        mapRefrence.getData(maxSize: 100 * 1024 * 1024) { data, error in
//            if let error = error {
//                print("Error while downloading map data: ", error)
//                fatalError("Error while downloading map data")
//            }
//            let worldMap: ARWorldMap = { () -> ARWorldMap in
//                do {
//                    guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data!)
//                        else { fatalError("No ARWorldMap in archive.") }
//                    
//                    return worldMap
//                } catch {
//                    fatalError("Can't unarchive ARWorldMap from file data: \(error)")
//                }
//            }()
//
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.setWorldMap(worldMap: world)
        }

//        }
    }
    
    func setWorldMap(worldMap: ARWorldMap) {
        worldMap.anchors.append(startPointSnapshotAnchor!)
        // Display the snapshot image stored in the world map to aid user in relocalizing.
        if let snapshotData = worldMap.snapshotAnchor?.imageData,
            let snapshot = UIImage(data: snapshotData) {
            self.snapshotThumbnail.image = snapshot
            self.snapshotThumbnail.layer.cornerRadius = 8.0
            self.snapshotThumbnail.clipsToBounds = true
            self.snapshotThumbnail.layer.masksToBounds = true
        } else {
            print("No snapshot image in world map")
        }
        // Remove the snapshot anchor from the world map since we do not need it in the scene.
        worldMap.anchors.removeAll(where: { $0 is SnapshotAnchor })
        
        let configuration = self.defaultConfiguration // this app's standard world tracking settings
        configuration.initialWorldMap = worldMap
        self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        self.isRelocalizingMap = true
        self.virtualObjectAnchor = nil
        self.isLoadingData = false
    }
    
    // Called opportunistically to verify that map data can be loaded from filesystem.
    var mapDataFromFile: Data? {
        return try? Data(contentsOf: mapSaveURL)
    }

    // MARK: - AR session management
    
    var isRelocalizingMap = false

    var defaultConfiguration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        configuration.sceneReconstruction = .meshWithClassification
        if #available(iOS 13.0, *), ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth)  {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
//            configuration.frameSemantics.insert(.sceneDepth)
        } else {
            print("people occlusion is not supported")
        }
        return configuration
    }
    
    @IBAction func resetTracking(_ sender: UIButton?) {
        sceneView.session.run(defaultConfiguration, options: [.resetTracking, .removeExistingAnchors])
        isRelocalizingMap = false
        virtualObjectAnchor = nil
    }
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        var message: String = ""
        
        snapshotThumbnail.isHidden = true
        switch (trackingState, frame.worldMappingStatus) {
            case (.normal, .mapped),
                 (.normal, .extending):
                if frame.anchors.contains(where: { $0.name == virtualObjectAnchorName }) {
                    if (!isCreatingPath) {
                        message = "Follow the disks to the destination"
                    } else {
                        // User has placed an object in scene and the session is mapped, prompt them to save the experience
                        message = "Tap 'Save Path' to save the current path"
                    }
                } else {
                    if (isCreatingPath) {
                        message = "Tap on the screen to place a disk"
                    } else {
                        message = "Move around to map the environment"
                    }
                }
                
            case (.normal, _) where mapDataFromFile != nil && !isRelocalizingMap:
                message = "Move around to map the environment"
                
            case (.normal, _) where mapDataFromFile == nil:
                message = "Move around to map the environment"
                
            case (.limited(.relocalizing), _) where isRelocalizingMap:
                message = "Move your device to the location shown in the image"
                snapshotThumbnail.isHidden = false
                
            default:
                message = trackingState.localizedFeedback
        }
        if (isLoadingData && !isCreatingPath) {
            message = "Downloading data"
        }
        
        sessionInfoLabel.text = message
        sessionInfoView.isHidden = message.isEmpty
    }
    
    // MARK: - Placing AR Content
    
    /// - Tag: PlaceObject
    @IBAction func handleSceneTap(_ sender: UITapGestureRecognizer) {
        // Disable placing objects when the session is still relocalizing
        if isRelocalizingMap && virtualObjectAnchor == nil {
            return
        }
        // Hit test to find a place for a virtual object.
        guard let query = sceneView.raycastQuery(from: sender.location(in: sceneView), allowing: .existingPlaneInfinite, alignment: .horizontal),
              let raycastResult = sceneView.session.raycast(query).first
            else { return }
        // 04/10/2021 - no longer doing arrows, rotation is not necessary - changed to disks
        // rotate to be the same direction as the phone and rotate the 3D arrow an additional 90 degrees (- 1.5708 radians)
        // so that it is not perpendicular, as it's default orientation
//        let rotate = simd_float4x4(SCNMatrix4MakeRotation(sceneView.session.currentFrame!.camera.eulerAngles.y - 1.5708, 0, 1, 0))
//        let rotateTransform = simd_mul(hitTestResult.worldTransform, rotate)
//        print("scene tap: name is ", virtualObjectAnchorName)

        virtualObjectAnchor = ARAnchor(name: virtualObjectAnchorName, transform: raycastResult.worldTransform)
        sceneView.session.add(anchor: virtualObjectAnchor!)
    }

    var virtualObjectAnchor: ARAnchor?
    let virtualObjectAnchorName = "virtualObject"



    // MARK: Walls detection
    

    func occlusion() -> SCNMaterial {

        let occlusionMaterial = SCNMaterial()
        occlusionMaterial.isDoubleSided = true
        occlusionMaterial.colorBufferWriteMask = []
        occlusionMaterial.readsFromDepthBuffer = true
        occlusionMaterial.writesToDepthBuffer = true

        return occlusionMaterial
    }

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let meshAnchor = anchor as? ARMeshAnchor else {
            return SCNNode()
        }

        let geometry = SCNGeometry(arGeometry: meshAnchor.geometry)

        let classification = meshAnchor.geometry.classificationOf(faceWithIndex: 0)
        switch classification {
        case .wall:
            break
        case .door:
            break
        default:
            return nil
        }

        let defaultMaterial = SCNMaterial()
        defaultMaterial.fillMode = .lines
        defaultMaterial.diffuse.contents = UIColor.red
        geometry.firstMaterial = occlusion()
        let node = SCNNode()
        node.geometry = geometry
        node.renderingOrder = -100
        node.categoryBitMask = 0b0001
        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let meshAnchor = anchor as? ARMeshAnchor else {
            return
        }

        let classification = meshAnchor.geometry.classificationOf(faceWithIndex: 0)


        switch classification {
        case .wall:
            break
        case .door:
            break
        case .window:
            break
        case .ceiling:
            break
        default:
            return
        }

        let newGeometry = SCNGeometry(arGeometry: meshAnchor.geometry)

        let defaultMaterial = SCNMaterial()
        defaultMaterial.fillMode = .lines
        defaultMaterial.diffuse.contents = UIColor.red
        newGeometry.firstMaterial = occlusion()
        node.geometry = newGeometry
    }

}

protocol ARPathCreatorViewControllerDelegate {
    func completedARWorldMapCreation(worldMapData: ARWorldMap, startImage: Data, endImage: Data)
}
