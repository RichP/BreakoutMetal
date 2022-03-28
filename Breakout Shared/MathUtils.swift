//
//  MathUtils.swift
//  multiplatform iOS
//
//  Created by Richard Pickup on 05/02/2022.
//

import simd

typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

let π = Float.pi

extension Float {
    var radiansToDegrees: Float {
        (self / π) * 180
    }
    
    var degreesToRadians: Float {
        (self / 180) * π
    }
}

extension float2 {
    func rotate(point: float2, angle: Float) -> float2 {
        let sinAngle = sin(angle)
        let cosAngle = cos(angle)
        var rx: Float = 0.0
        var ry: Float = 0.0
        if point.x.isZero {
            let tempX = x * cosAngle - y * sinAngle
            ry = y * cosAngle + x * sinAngle
            rx = tempX
        } else {
            let tempX = x - point.x
            let tempY = y - point.y
            rx = tempX * cosAngle - tempY * sinAngle + point.x
            ry = tempY * cosAngle + tempX * sinAngle + point.y
        }
        return float2(x: rx, y: ry)
    }
}

extension float4 {
    var xyz: float3 {
        get {
            float3(x, y, z)
        }
        set {
            x = newValue.x
            y = newValue.y
            z = newValue.z
        }
    }
    
}

struct Rectangle {
  var left: Float = 0
  var right: Float = 0
  var top: Float = 0
  var bottom: Float = 0
}

extension float4x4 {
    static func identity() -> float4x4 {
        return matrix_identity_float4x4
    }
    
    var upperLeft: float3x3 {
        let x = columns.0.xyz
        let y = columns.1.xyz
        let z = columns.2.xyz
        return float3x3(columns: (x, y, z))
    }
    
    init(translation: float3) {
        let matrix = float4x4(
            [1,0,0,0],
            [0,1,0,0],
            [0,0,1,0],
            [translation.x,translation.y,translation.z,1])
        self = matrix
    }
    
    init(rotationX angle: Float) {
        let matrix = float4x4(
            [1,0,0,0],
            [0,cos(angle),sin(angle),0],
            [0,-sin(angle),cos(angle),0],
            [0,0,0,1])
        self = matrix
    }
    
    init(rotationY angle: Float) {
        let matrix = float4x4(
            [cos(angle),0,-sin(angle),0],
            [0,1,0,0],
            [sin(angle),0,cos(angle),0],
            [0,0,0,1])
        self = matrix
    }
    
    init(rotationZ angle: Float) {
        let matrix = float4x4(
            [cos(angle),sin(angle),0,0],
            [-sin(angle),cos(angle),0,0],
            [0,0,1,0],
            [0,0,0,1])
        self = matrix
    }
    
    init(rotation angle: float3) {
        let rotationX = float4x4(rotationX: angle.x)
        let rotationY = float4x4(rotationY: angle.y)
        let rotationZ = float4x4(rotationZ: angle.z)
        
        self = rotationX * rotationY * rotationZ
    }
    
    init(rotationYXZ angle: float3) {
        let rotationX = float4x4(rotationX: angle.x)
        let rotationY = float4x4(rotationY: angle.y)
        let rotationZ = float4x4(rotationZ: angle.z)
        
        self = rotationY * rotationX * rotationZ
    }
    
    
    init(scaling: float3) {
        
        let matrix = float4x4(
            [scaling.x,0,0,0],
            [0,scaling.y,0,0],
            [0,0,scaling.z,0],
            [0,0,0,1])
        self = matrix
        
    }
    
    init(orthographic rect: Rectangle, near: Float, far: Float) {
        let x = float4(2 / (rect.right - rect.left), 0, 0, 0)
        let y = float4(0, 2 / (rect.top - rect.bottom), 0, 0)
        let z = float4(0, 0, 1 / (far - near), 0)
        let w = float4((rect.left + rect.right) / (rect.left - rect.right),
                       (rect.top + rect.bottom) / (rect.bottom - rect.top),
                       near / (near - far),
                       1)
        self.init()
        columns = (x,y,z,w)
    }

    
    init(projectionFov fov: Float, near: Float, far: Float, aspect: Float, lhs: Bool = true) {
        let y = 1 / tan(fov * 0.5)
        let x = y / aspect
        let z = lhs ? far / (far - near) : far / (near - far)
        let X = float4( x, 0, 0, 0)
        let Y = float4( 0, y, 0, 0)
        let Z = lhs ? float4( 0, 0, z, 1) : float4( 0, 0, z, -1)
        let W = lhs ? float4( 0, 0, z * -near, 0) : float4( 0, 0, z * near, 0)
        
        self.init()
        columns = (X, Y, Z, W)
    }
}
