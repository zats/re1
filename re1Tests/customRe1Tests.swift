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
        describe("sequenceLiteral") {
            it("yield correct range") {
                let re: RegularExpression<String> = .Parentheses(.Sequence({
                        let str: String = $0.reduce("", combine: +) // compiler aid
                        return str == "hello"
                }), n: 0)
                let input = "hello"
                let ranges = match(re, input)
                expect(ranges).to(equal([0..<5]))
            }
        }
        
        describe("and") {
            it("iterates over the same instructions") {
                let re: RegularExpression<String> = .Parentheses(.And(
                    .Sequence({
                        let str: String = $0.reduce("", combine: +) // compiler aid
                        return str == "hello"
                    }),
                    .Sequence({
                        let str: String = $0.reduce("", combine: +)  // compiler aid
                        return str == "hello"
                    })
                ), n: 0)
                let input = "hello"
                let ranges = match(re, input)
                expect(ranges).to(equal([0..<5]))
            }
            
            it("returns shortest match length") {
                let re: RegularExpression<String> = .Parentheses(.And(
                    .Sequence({
                        let str: String = $0.reduce("", combine: +) // compiler aid
                        return str == "hello"
                    }),
                    .cat(
                        .literal("h"),
                        .literal("e"),
                        .literal("l"),
                        .literal("l")
                    )
                ), n: 0)
                let input = "hello"
                let ranges = match(re, input)
                expect(ranges).to(equal([0..<4]))
            }
        }
    }
}
