//
//  Parser.swift
//  re1
//
//  Created by Sash Zats on 4/29/16.
//  Copyright © 2016 Sash Zats. All rights reserved.
//

import re1

typealias StringGenerator = IndexingGenerator<String.CharacterView>

func parse(generator: String) -> Regexp<String>? {
    var stack: [Regexp<String>] = []
    var parantCount = 1
    parse(generator.characters.generate(), stack: &stack, parantCount: &parantCount)
    let re = stack.removeLast()
    assert(stack.isEmpty)
    return .Cat(.Star(.Dot, greedy: false), .Paren(re, n:0))
}

private func parse(generator: StringGenerator, inout stack: [Regexp<String>], inout parantCount: Int) {
    var generator = generator
    guard let first = generator.next() else { return }
    var char = String(first)
    switch char {
    case "*":
        stack.append(.Star(stack.removeLast(), greedy: true))
    case "+":
        stack.append(.Plus(stack.removeLast(), greedy: true))
    case "?":
        stack.append(.Quest(stack.removeLast(), greedy: true))
    case "(":
        let substr = parenSubstr(&generator)
        var substack: [Regexp<String>] = []
        let localParentCont = parantCount
        parantCount += 1
        parse(substr.characters.generate(), stack: &substack, parantCount: &parantCount)
        let subre = substack.removeFirst()
        assert(substack.isEmpty)
        if stack.isEmpty {
            stack.append(.Paren(subre, n: localParentCont))
        } else {
            stack.append(.Cat(stack.removeLast(), lookahead(&generator, .Paren(subre, n: localParentCont))))
        }
    case ".":
        if stack.isEmpty {
            stack.append(.Dot)
        } else {
            stack.append(.Cat(stack.removeLast(), lookahead(&generator, .Dot)))
        }
    case "|":
        var substack: [Regexp<String>] = []
        parse(generator, stack: &substack, parantCount: &parantCount)
        let right = substack.removeLast()
        assert(substack.isEmpty)
        stack.append(.Alt(stack.removeLast(), right))
        return
    case "\\":
        // treat next char as literal
        guard let c = generator.next() else { fatalError() }
        char = String(c)
        fallthrough
    default:
        if stack.isEmpty {
            stack.append(.literal(char))
        } else {
            stack.append(.Cat(stack.removeLast(), lookahead(&generator, .literal(char))))
        }
    }
    parse(generator, stack: &stack, parantCount: &parantCount)
}

private func lookahead(inout generator: StringGenerator, _ regex: Regexp<String>) -> Regexp<String> {
    var localGenerator = generator
    guard let c = localGenerator.next() else { return regex }
    let char = String(c)
    let re: Regexp<String>
    switch char {
    case "+":
        re = .Plus(regex, greedy: true)
    case "*":
        re = .Star(regex, greedy: true)
    case "?":
        re = .Quest(regex, greedy: true)
    default:
        return regex
    }
    generator = localGenerator
    return re
}

private func parenSubstr(inout generator: StringGenerator) -> String {
    var localGenerator = generator
    var counter = 1
    var result = ""
    while counter > 0 {
        if let char = localGenerator.next() {
            let char = String(char)
            if char == "(" {
                counter += 1
            } else if char == ")" {
                counter -= 1
            }
            if char != ")" || counter > 0 {
                result += char
            }
        }
    }
    if counter > 0 { fatalError() }
    generator = localGenerator
    return result
}