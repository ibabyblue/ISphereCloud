//
//  ISphereCloudTests.swift
//  ISphereCloudTests
//
//  Created by ibabyblue on 2026/06/15.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import XCTest
import simd
@testable import ISphereCloud

final class SphereMathLayoutTests: XCTestCase {

    func test_fibonacciSphere_returnsRequestedCount() {
        XCTAssertEqual(SphereMath.fibonacciSphere(count: 40).count, 40)
    }

    func test_fibonacciSphere_allPointsOnUnitSphere() {
        for p in SphereMath.fibonacciSphere(count: 200) {
            XCTAssertEqual(simd_length(p), 1.0, accuracy: 1e-9)
        }
    }

    func test_fibonacciSphere_zeroOrNegative_returnsEmpty() {
        XCTAssertTrue(SphereMath.fibonacciSphere(count: 0).isEmpty)
        XCTAssertTrue(SphereMath.fibonacciSphere(count: -5).isEmpty)
    }

    func test_fibonacciSphere_single_isUnitLength() {
        let pts = SphereMath.fibonacciSphere(count: 1)
        XCTAssertEqual(pts.count, 1)
        XCTAssertEqual(simd_length(pts[0]), 1.0, accuracy: 1e-9)
    }
}

final class SphereMathRotationTests: XCTestCase {

    private func isOrthonormal(_ m: simd_double3x3, accuracy: Double = 1e-9) -> Bool {
        let shouldBeIdentity = m.transpose * m
        let i = matrix_identity_double3x3
        for col in 0..<3 {
            for row in 0..<3 {
                if abs(shouldBeIdentity[col][row] - i[col][row]) > accuracy { return false }
            }
        }
        return abs(simd_determinant(m) - 1.0) <= accuracy
    }

    func test_zeroDelta_isIdentity() {
        let m = SphereMath.rotationMatrix(deltaX: 0, deltaY: 0, sensitivity: 1)
        XCTAssertEqual(simd_determinant(m), 1.0, accuracy: 1e-9)
        let v = SIMD3<Double>(0.3, 0.4, 0.866)
        let r = m * v
        XCTAssertEqual(simd_length(r - v), 0, accuracy: 1e-9)
    }

    func test_rotationMatrix_isOrthonormal() {
        XCTAssertTrue(isOrthonormal(SphereMath.rotationMatrix(deltaX: 0.7, deltaY: -0.3, sensitivity: 1)))
    }

    func test_composedRotations_stayOrthonormal() {
        var m = matrix_identity_double3x3
        for k in 0..<50 {
            m = SphereMath.rotationMatrix(deltaX: Double(k) * 0.11,
                                          deltaY: Double(k) * -0.07,
                                          sensitivity: 0.5) * m
        }
        XCTAssertTrue(isOrthonormal(m, accuracy: 1e-7))
    }

    func test_rotation_preservesLength() {
        let m = SphereMath.rotationMatrix(deltaX: 1.2, deltaY: 0.9, sensitivity: 1)
        let p = SIMD3<Double>(1, 0, 0)
        XCTAssertEqual(simd_length(m * p), 1.0, accuracy: 1e-9)
    }

    func test_rotationY_rotatesXTowardNegativeZ() {
        // +deltaX -> rotationY(+θ); (1,0,0) should swing toward -Z
        let m = SphereMath.rotationMatrix(deltaX: .pi / 2, deltaY: 0, sensitivity: 1)
        let r = m * SIMD3<Double>(1, 0, 0)
        XCTAssertEqual(simd_length(r - SIMD3(0, 0, -1)), 0, accuracy: 1e-9)
    }

    func test_rotationX_rotatesYTowardPositiveZ() {
        // +deltaY -> rotationX(+θ); (0,1,0) should swing toward +Z
        let m = SphereMath.rotationMatrix(deltaX: 0, deltaY: .pi / 2, sensitivity: 1)
        let r = m * SIMD3<Double>(0, 1, 0)
        XCTAssertEqual(simd_length(r - SIMD3(0, 0, 1)), 0, accuracy: 1e-9)
    }
}
