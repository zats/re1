//
//  re1Tests.swift
//  re1
//
//  Created by Sash Zats on 5/2/16.
//  Copyright © 2016 Sash Zats. All rights reserved.
//

import Quick
import Nimble
@testable import re1

class re1Tests: QuickSpec {
    override func spec() {
        sharedExamples("regex") { (fn: () -> NSDictionary) in
            let params = fn()
            guard let testIndex = params["index"] as? Int,
                regexString = params["regex"] as? String,
                regex = parse(regexString),
                string = params["string"] as? String,
                rangeString = params["matches"] as? String,
                matchRanges = rangesFromString(rangeString) else {
                    fail("Missing parameters")
                    return
            }
            let ranges = match(regex, string)
            it("\(testIndex) \(regexString) \(rangeString)") {
                expect(ranges).to(equal(matchRanges))
            }
        }
        
        describe("shared example test") {
            let bundle = NSBundle(forClass: re1Tests.self)
            guard let URL = bundle.URLForResource("tests", withExtension: nil) else {
                fail("tests file not found")
                return
            }
            let testFile = try! String(contentsOfURL: URL)
            let tests = parseTestsFile(testFile)
            it("...") {
                tests.forEach { component in
                    itBehavesLike("regex", sharedExampleContext: {
                        return [
                            "index": component.index,
                            "regex": component.regex,
                            "string": component.string,
                            "matches": component.ranges
                        ]
                    })
                }
            }
        }
        
        fdescribe("and") {
            it("should iterate over same instructions") {
                let re: Regexp<String> = .Paren(.And(.Literal({
                    $0.uppercaseString == "H"
                }), .Literal({
                    $0 == "h"
                })), n: 0)
                let input = "hello"
                let ranges = match(re, input)
                expect(ranges).to(equal([0..<1]))
            }
        }
        
    }
}

func match(re: Regexp<String>, _ input: String) -> [Range<Int>] {
    return re.match(input.characters.map{String($0)})
}

private func parseTestsFile(file: String) -> [(index: Int, regex: String, string: String, ranges: String)] {
    return file.componentsSeparatedByString("\n").flatMap {
        let components = $0.componentsSeparatedByCharactersInSet(.whitespaceCharacterSet()).filter{ !$0.characters.isEmpty }
        if components.count != 4 { return nil }
        guard let index = Int(components[0]) else {
            return nil
        }
        let regex = components[1]
        let string = components[2]
        let rangeString = components[3]
        return (index, regex, string, rangeString)
    }
}

private func rangesFromString(string: String) -> [Range<Int>]? {
    let scanner = NSScanner(string: string)
    var ranges: [Range<Int>] = []
    
    while !scanner.atEnd {
        guard scanner.scanString("(", intoString: nil) else { return nil }
        var start: Int32 = 0
        guard scanner.scanInt(&start) else { return nil }
        guard scanner.scanString(",", intoString: nil) else { return nil }
        var end: Int32 = 0
        guard scanner.scanInt(&end) else { return nil }
        guard scanner.scanString(")", intoString: nil) else { return nil }
        
        ranges.append(Int(start)..<Int(end))
    }
    return ranges
}