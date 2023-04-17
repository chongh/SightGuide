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
    static var params: BasicParams?
    
    static func Setup() {
        // init log
        let console = ConsoleDestination()
        let file = FileDestination()
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        file.logFileURL = url.appendingPathComponent("SightGuide.log")
        file.minLevel = SwiftyBeaver.Level.verbose
        log.addDestination(console)
        log.addDestination(file)
        
        // get params
        NetworkRequester.getParams(completion:{ result in
            switch result {
            case .success(let params):
                self.params = params
            case .failure(let error):
                print("Error: \(error)")
            }        })
    }
}
