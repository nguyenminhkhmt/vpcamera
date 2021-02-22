//
//  RecordSessionModel.swift
//  VPGCamera
//
//  Created by Minh Nguyen Duc on 1/12/20.
//  Copyright © 2020 ahdenglish. All rights reserved.
//

import Foundation

// MARK: - RecordSessionModel
struct RecordSessionModel: Codable {
    var from: Int?
    var createdOn: Date = Date()
    var timeECGPressed: Date?
    var tsECGPressed: Int?
    var timeVideoRecorded: String?
    var tsVideoRecorded: Int?
    var isFront: Bool?
    var similarity, tsMotion: Int?
    var motion: [Double]?
    var duration, fps: Int?
    var avROI: [Int]?
    var uniquePatientCode, serialNo: String?
    var patientID, totalFrames: Int?
    var frames: [Frame]?
    var videoName: String?

    enum CodingKeys: String, CodingKey {
        case from, createdOn, timeECGPressed, tsECGPressed, timeVideoRecorded, tsVideoRecorded, isFront, similarity, tsMotion, motion, duration, fps, avROI, uniquePatientCode, serialNo
        case patientID = "patientId"
        case totalFrames, frames
        case videoName
    }
}

// MARK: - Frame
struct Frame: Codable {
    var id, faceDetected: Int?
    var r, g, b: Double?
    var roi: [Double]?

    enum CodingKeys: String, CodingKey {
        case id, faceDetected, r, g, b
        case roi = "ROI"
    }
}
