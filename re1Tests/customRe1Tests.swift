//
//  customRe1Tests.swift
//  re1
//
//  Created by Sash Zats on 5/10/16.
//  Copyright © 2016 Sash Zats. All rights reserved.
//

import Quick
import Nimble
@testable import re1

class customRe1Tests: QuickSpec {
    override func spec() {
        describe("and") {
            it("should iterate over same instructions") {
                let re: Regexp<String> = .Paren(.And(
                    .SequenceLiteral({
                        let str: String = $0.reduce("", combine: +) // compiler aid
                        return str == "hello"
                    }),
                    .SequenceLiteral({
                        let str: String = $0.reduce("", combine: +)  // compiler aid
                        return str == "hello"
                    })
                ), n: 0)
                let input = "hello"
                let ranges = match(re, input)
                expect(ranges).to(equal([0..<5]))
            }
        }
    }
}
