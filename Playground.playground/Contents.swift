//: Playground - noun: a place where people can play

import UIKit
import re1


private extension UIColor {
    var hue: CGFloat {
        var hue: CGFloat = 0
        getHue(&hue, saturation: nil, brightness: nil, alpha: nil)
        return hue
    }

    var brightness: CGFloat {
        var brightness: CGFloat = 0
        getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        return brightness
    }

    var saturation: CGFloat {
        var saturation: CGFloat = 0
        getHue(nil, saturation: &saturation, brightness: nil, alpha: nil)
        return saturation
    }

    var red: CGFloat {
        var red: CGFloat = 0
        getRed(&red, green: nil, blue: nil, alpha: nil)
        return red
    }
    
    var green: CGFloat {
        var green: CGFloat = 0
        getRed(nil, green: &green, blue: nil, alpha: nil)
        return green
    }
    
    var blue: CGFloat {
        var blue: CGFloat = 0
        getRed(nil, green: nil, blue: &blue, alpha: nil)
        return blue
    }
}


let colors = [[#Color(colorLiteralRed: 0.3921568627, green: 0.662745098, blue: 0.1254901961, alpha: 1)#], [#Color(colorLiteralRed: 0.7490196078, green: 0.09803921569, blue: 0.02352941176, alpha: 1)#], [#Color(colorLiteralRed: 0, green: 0.4980392157, blue: 1, alpha: 1)#], [#Color(colorLiteralRed: 0.9921568627, green: 0.9254901961000001, blue: 0.6980392157, alpha: 1)#], [#Color(colorLiteralRed: 0.9647058824, green: 0.6745098039, blue: 0.1137254902, alpha: 1)#], [#Color(colorLiteralRed: 1, green: 0.4, blue: 0.4, alpha: 1)#]]
let regex: RegularExpression<UIColor> = .cat(
    .Literal({ (color: UIColor) -> Bool in
        color.red > color.blue && color.red > color.green
    }),
    .Literal({ (color: UIColor) -> Bool in
        color.blue > color.red && color.blue > color.green
    })
)
assert(regex.match(colors) == [1..<3])





