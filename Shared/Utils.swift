//
//  CanvasViewer.swift
//  whiteboard
//
//  Created by alec on 4/10/25.
//

import Foundation
import UIKit

func getCanvasDimensions(for screenWidth: CGFloat) -> (width: CGFloat, height: CGFloat) {
    // Logic based on the table for Large widget sizes
    let screenHeight = UIScreen.main.bounds.height
    
    // Default to smallest Large widget size
    var widgetWidth: CGFloat = 292
    var widgetHeight: CGFloat = 311
    
    let screenSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    
    if screenSize.width >= 430 && screenSize.height >= 932 {
        widgetWidth = 364
        widgetHeight = 382
    } else if screenSize.width >= 428 && screenSize.height >= 926 {
        widgetWidth = 364
        widgetHeight = 382
    } else if screenSize.width >= 414 && screenSize.height >= 896 {
        widgetWidth = 360
        widgetHeight = 379
    } else if screenSize.width >= 414 && screenSize.height >= 736 {
        widgetWidth = 348
        widgetHeight = 357
    } else if screenSize.width >= 393 && screenSize.height >= 852 {
        widgetWidth = 338
        widgetHeight = 354
    } else if screenSize.width >= 390 && screenSize.height >= 844 {
        widgetWidth = 338
        widgetHeight = 354
    } else if screenSize.width >= 375 && screenSize.height >= 812 {
        widgetWidth = 329
        widgetHeight = 345
    } else if screenSize.width >= 375 && screenSize.height >= 667 {
        widgetWidth = 321
        widgetHeight = 324
    } else if screenSize.width >= 360 && screenSize.height >= 780 {
        widgetWidth = 329
        widgetHeight = 345
    } else if screenSize.width >= 320 && screenSize.height >= 568 {
        widgetWidth = 292
        widgetHeight = 311
    }
    
    print("Device screen: \(screenSize), Widget dimensions: \(widgetWidth) x \(widgetHeight)")
    
    return (widgetWidth, widgetHeight)
}
