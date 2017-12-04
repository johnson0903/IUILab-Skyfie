//
//  FlightInfo.swift
//  Skyfie_on_Spark
//
//  Created by 李嘉晟 on 2017/11/21.
//  Copyright © 2017年 康平. All rights reserved.
//

import Foundation

class FlightInfo {
    var _direction: FineTuningDirection
    var _mode: FlightMode
    
    init(direction: FineTuningDirection, mode: FlightMode) {
        self._direction = direction
        self._mode = mode
    }
}
