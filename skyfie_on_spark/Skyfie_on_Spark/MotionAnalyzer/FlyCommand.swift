//
//  FlyCommand.swift
//  FlyHighHigh
//
//  Created by iuilab on 2016/7/5.
//  Copyright © 2016年 iuilab. All rights reserved.
//

import Foundation
struct FlyCommand {
    private var realCommand : Dictionary <String, Float> = ["left": 0, "right": 0, "front": 0, "back": 0, "up": 0, "down": 0]
    private var rotate: Float = 0.0
    var left: Float{
        set{
            if newValue > 15 {
                realCommand["left"] = 15
            }else if newValue < 0{
                realCommand["left"] = -newValue
            }else{
                realCommand["left"] = newValue
            }
        }
        get{
            return realCommand["left"]!
        }
    }
    var right: Float{
        set{
            if newValue > 15 {
                realCommand["right"] = 15
            }else if newValue < 0{
                realCommand["right"] = -newValue
            }else{
                realCommand["right"] = newValue
            }
        }
        get{
            return realCommand["right"]!
        }
    }

    var front: Float{
        set{
            if newValue > 15 {
                realCommand["front"] = 15
            }else if newValue < 0{
                realCommand["front"] = -newValue
            }else{
                realCommand["front"] = newValue
            }
        }
        get{
            return realCommand["front"]!
        }
    }

    var back: Float{
        set{
            if newValue > 15 {
                realCommand["back"] = 15
            }else if newValue < 0{
                realCommand["back"] = -newValue
            }else{
                realCommand["back"] = newValue
            }
        }
        get{
            return realCommand["back"]!
        }
    }

    var up: Float{
        set{
            if newValue > 15 {
                realCommand["up"] = 15
            }else if newValue < 0{
                realCommand["up"] = -newValue
            }else{
                realCommand["up"] = newValue
            }
        }
        get{
            return realCommand["up"]!
        }
    }

    var down: Float{
        set{
            if newValue > 15 {
                realCommand["down"] = 15
            }else if newValue < 0{
                realCommand["down"] = -newValue
            }else{
                realCommand["down"] = newValue
            }
        }
        get{
            return realCommand["down"]!
        }
    }
    var rotation: Float{
        set{
            if abs(newValue) > 0  {
                rotate = newValue
            }
        }
        get{
            return rotate
        }
    }
    func clone() -> FlyCommand {
        
        return self
    }
}
