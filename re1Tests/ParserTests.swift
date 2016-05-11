//
//  ParserTests.swift
//  ParserTests
//
//  Created by Sash Zats on 4/28/16.
//  Copyright © 2016 Sash Zats. All rights reserved.
//

import Quick
import Nimble
@testable import re1

class ParserTests: QuickSpec {
    override func spec() {
        describe("parsing") {
            sharedExamples("parser") { (ctx: () -> NSDictionary) in
                let params = ctx()
                guard let string = params["string"] as? String,
                    regexBox = params["regex"] as? Box else {
                        fail()
                        return
                }
                guard let result = parse(string) else {
                    fail()
                    return
                }
                it("should parse \(string) correctly") {
                    expect(regexBox.unbox == result).to(beTrue())
                }
            }
            
            itBehavesLike("parser") {
                return [
                    "string": "a(b)",
                    
                    "regex": Box(.Cat(.literal("a"), .Parentheses(.literal("b"), n: 0)))
                ]
            }

            itBehavesLike("parser") {
                return [
                    "string": "(ab*)",
                    "regex": Box(.Parentheses(.Cat(.literal("a"), .Star(.literal("b"), greedy: true)), n: 0))
                ]
            }

            itBehavesLike("parser") {
                return [
                    "string": "(ab*)*",
                    "regex": Box(.Star(.Parentheses(.Cat(.literal("a"), .Star(.literal("b"), greedy: true)), n: 0), greedy: true))
                ]
            }

            itBehavesLike("parser") {
                return [
                    "string": "(a(b))",
                    "regex": Box(.Parentheses(.Cat(.literal("a"), .Parentheses(.literal("b"), n: 1)), n: 0))
                ]
            }
            
            itBehavesLike("parser") {
                return [
                    "string": "(a)(b)",
                    "regex": Box(.Cat(.Parentheses(.literal("a"), n: 0), .Parentheses(.literal("b"), n: 1)))
                ]
            }

            itBehavesLike("parser") {
                return [
                    "string": "abc",
                    "regex": Box(.Cat(.Cat(.literal("a"), .literal("b")), .literal("c")))
                ]
            }

            itBehavesLike("parser") {
                return [
                    "string": "(..)*(...)*",
                    "regex": Box(.Cat(.Star(.Parentheses(.Cat(.Dot, .Dot), n: 0), greedy: true), .Star(.Parentheses(.Cat(.Cat(.Dot, .Dot), .Dot), n: 1), greedy: true)))
                ]
            }

            itBehavesLike("parser") {
                return [
                    "string": "ab|c",
                    "regex": Box(.Alt(.Cat(.literal("a"), .literal("b")), .literal("c")))
                ]
            }

            itBehavesLike("parser") {
                return [
                    "string": "(aa|aaa)*|(a|aaaaa)",
                    "regex": Box(.Alt(.Star(.Parentheses(.Alt(.Cat(.literal("a"), .literal("a")), .Cat(.Cat(.literal("a"), .literal("a")), .literal("a"))), n: 0), greedy: true), .Parentheses(.Alt(.literal("a"), .Cat(.Cat(.Cat(.Cat(.literal("a"), .literal("a")), .literal("a")), .literal("a")), .literal("a"))), n: 1)))
                ]
            }
        }
    }
}

private class Box {
    let unbox: RegularExpression<String>
    init(_ boxed: RegularExpression<String>) {
        self.unbox = .Cat(.Star(.Dot, greedy: false), .Parentheses(Box.shiftParen(boxed), n:0))
    }
    
    static func shiftParen(boxed: RegularExpression<String>) -> RegularExpression<String> {
        switch boxed {
        case let .Parentheses(re, n):
            return .Parentheses(shiftParen(re), n: n + 1)
        case let .Cat(left, right):
            return .Cat(shiftParen(left), shiftParen(right))
        case let .Alt(left, right):
            return .Alt(shiftParen(left), shiftParen(right))
        case let .Plus(re, greedy):
            return .Plus(shiftParen(re), greedy: greedy)
        case let .Star(re, greedy):
            return .Star(shiftParen(re), greedy: greedy)
        case let .Quest(re, greedy):
            return .Quest(shiftParen(re), greedy: greedy)
        default:
            return boxed
        }
    }
}

extension RegularExpression: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var debugDescription: String {
        return description
    }
    
    public var description: String {
        switch self {
        case .Dot:
            return "dot"
        case let .Literal(predicate):
            return "literal(\(predicate))"
        case let .Sequence(predicate):
            return "sequenceLiteral(\(predicate))"
        case let .Parentheses(re, n):
            return "paren(\(re), \(n))"
        case let .Cat(left, right):
            return "cat(\(left), \(right))"
        case let .Alt(left, right):
            return "alt(\(left), \(right))"
        case let .Plus(re, greedy):
            return "plus(\(re), \(greedy))"
        case let .Star(re, greedy):
            return "star(\(re), \(greedy))"
        case let .Quest(re, greedy):
            return "quest(\(re), \(greedy))"
        case let .And(left, right):
            return "and(\(left), \(right))"
        }
    }
}

public func ==<T: Equatable>(lhs: RegularExpression<T>, rhs: RegularExpression<T>) -> Bool {
    switch (lhs, rhs) {
    case let (.Parentheses(re1, depth1), .Parentheses(re2, depth2)):
        return re1 == re2 && depth1 == depth2
    case let (.Star(re1, greedy1), .Star(re2, greedy2)):
        return greedy1 == greedy2 && re1 == re2
    case let (.Plus(re1, greedy1), .Plus(re2, greedy2)):
        return greedy1 == greedy2 && re1 == re2
    case (.Dot, .Dot):
        return true
    case let (.Cat(l1, r1), .Cat(l2, r2)):
        return l1 == l2 && r1 == r2
    case let (.Quest(re1, greedy1), .Quest(re2, greedy2)):
        return greedy1 == greedy2 && re1 == re2
    case let (.Literal(l1), .Literal(l2)):
        return true//l1 == l2
    case let (.Alt(l1, r1), .Alt(l2, r2)):
        return l1 == l2 && r1 == r2
    default:
        return false
    }
}