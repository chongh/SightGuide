//
//  LogHelper.swift
//  SightGuide
//
//  Created by linhz on 2023/4/13.
//

import SwiftyBeaver
import Foundation

final class LogHelper {
    static var log = SwiftyBeaver.self
    static var UserId = "0"
    
    static func Setup() {
        // init log
        let console = ConsoleDestination()
        let file = FileDestination()
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        file.logFileURL = url.appendingPathComponent("SightGuide."+dateString+".log")
        file.minLevel = SwiftyBeaver.Level.verbose
        log.addDestination(console)
        log.addDestination(file)
    }
}
