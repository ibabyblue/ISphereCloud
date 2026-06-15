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
