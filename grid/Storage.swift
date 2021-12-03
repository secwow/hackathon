//
//  Storage.swift
//  grid
//
//  Created by Dmytro Rebenko on 02.12.2021.
//

import Foundation

import UIKit
import ARKit

class Storage {
    static var worldMapData: [String: Data] = [:]
    static var paths: [UUID: [String: String]] = [:]
    static var pathStartImage: [String: Data] = [:]

    static var startImage: SnapshotAnchor?
    static var endImage: SnapshotAnchor?
    static var worldData: ARWorldMap?
}
