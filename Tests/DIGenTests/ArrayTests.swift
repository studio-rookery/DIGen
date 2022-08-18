//
//  ArrayTests.swift
//  
//
//  Created by masaki on 2022/08/06.
//

import XCTest

@testable import DIGen

final class ArrayTests: XCTestCase {

    func test_filterUnique() {
        XCTAssertEqual([1, 2, 2, 3, 4, 4, 5].filterUnique(), [1, 3, 5])
    }
}
