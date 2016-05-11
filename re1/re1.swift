//
//  re1.swift
//  re1
//  Based on recursive version of https://swtch.com/~rsc/regexp/regexp2.html
//  Created by Sash Zats on 4/29/16.
//  Copyright © 2016 Sash Zats. All rights reserved.
//



public indirect enum RegularExpression<T: Equatable> {
    case Parentheses(RegularExpression, n: Int)
    case Star(RegularExpression, greedy: Bool)
    case Dot
    case Cat(RegularExpression, RegularExpression)
    case Literal(T -> Bool)
    /**
     Intended for checks on the entire sequence.
     
     If inside of parentheses, yields entire sequence range
     *iff* `true`, or empty range *iff* returns `false`.
     */
    case Sequence([T] -> Bool)
    case Plus(RegularExpression, greedy: Bool)
    case Quest(RegularExpression, greedy: Bool)
    case Alt(RegularExpression, RegularExpression)
    case And(RegularExpression, RegularExpression)
    
    private func preprocessed() -> RegularExpression {
        let r: RegularExpression = .Parentheses(self, n: 0)
        let dotStar: RegularExpression = .Star(.Dot, greedy: false)
        return .Cat(dotStar, r)
    }
}

public extension RegularExpression {
    public static func literal(value: T) -> RegularExpression {
        return .Literal({ $0 ==  value})
    }

    public static func cat(regexes: RegularExpression<T> ...) -> RegularExpression<T> {
        return regexes.dropFirst().reduce(regexes.first!) { .Cat($0, $1) }
    }
}

public extension RegularExpression {
    public func match(input: [T]) -> [Range<Int>] {
        let re = self.preprocessed()
        let instructions = Emitter.emit(re)
        guard let capture = Engine.recursive(instructions: instructions, index: 0, input: input) else {
            fatalError()
        }
        return capture
    }
}

/**
  Unlike original version, this one operates on indexes to avoid dealing with references
 */
private enum Opcode<T: Equatable> {
    case Sequence([T] -> Bool)
    case Literal(T -> Bool)
    case Match
    case Jump(Int)
    case Split(Int, Int)
    case Any
    case Save(Int)
}

private class Instruction<T: Equatable> {
    var opcode: Opcode<T>
    
    init(_ opcode: Opcode<T>) {
        self.opcode = opcode
    }
}

private struct Emitter<T: Equatable> {
    static func emit(r: RegularExpression<T>) -> [Instruction<T>] {
        var instructions: [Instruction<T>] = []
        emit(r, instructions: &instructions)
        instructions.append(Instruction(.Match))
        return instructions
    }
    
    static func emit(r: RegularExpression<T>, inout instructions i: [Instruction<T>]) {
        switch r {
        case let .Cat(left, right):
            //      codes for e1
            //      codes for e2
            emit(left, instructions: &i)
            emit(right, instructions: &i)
        case .Dot:
            let pc = Instruction<T>(.Any)
            i.append(pc)
        case let .Star(r, greedy):
            //  L1: split L2, L3
            //  L2: codes for e
            //      jmp L1
            //  L3:
            let split = Instruction<T>(.Any)
            let splitIndex = i.count
            i.append(split)
            emit(r, instructions: &i)
            let jmp = Instruction<T>(.Jump(splitIndex))
            let jmpIndex = i.count
            split.opcode = .Split(splitIndex + 1, jmpIndex + 1)
            i.append(jmp)
            if !greedy {
                split.opcode = .Split(jmpIndex + 1, splitIndex + 1)
            }
        case let .Parentheses(r, n):
            let pc = Instruction<T>(.Save(2 * n))
            i.append(pc)
            emit(r, instructions: &i)
            let pc2 = Instruction<T>(.Save(2 * n + 1))
            i.append(pc2)
        case let .Sequence(predicate):
            let pc = Instruction(.Sequence(predicate))
            i.append(pc)
        case let .Literal(predicate):
            let pc = Instruction(.Literal(predicate))
            i.append(pc)
        case let .Plus(regexp, greedy):
            //  L1: codes for e
            //      split L1, L3
            //  L3:
            let index = i.count
            emit(regexp, instructions: &i)
            let splitIndex = i.count
            let split = Instruction<T>(.Split(index, splitIndex + 1))
            i.append(split)
            if !greedy {
                split.opcode = .Split(splitIndex + 1, index)
            }
        case let .Quest(regexp, greedy):
            //      split L1, L2
            //  L1: codes for e1
            //  L2:
            let split = Instruction<T>(.Any)
            i.append(split)
            let leftIndex = i.count
            emit(regexp, instructions: &i)
            let rightIndex = i.count
            if greedy {
                split.opcode = .Split(leftIndex, rightIndex)
            } else {
                split.opcode = .Split(rightIndex, leftIndex)
            }
        case let .Alt(left, right):
            //      split L1, L2
            //  L1: codes for e1
            //      jmp L3
            //  L2: codes for e2
            //  L3:
            let split = Instruction<T>(.Any)
            i.append(split)
            let leftIndex = i.count
            emit(left, instructions: &i)
            let jmp = Instruction<T>(.Any)
            i.append(jmp)
            let rightIndex = i.count
            emit(right, instructions: &i)
            let exitIndex = i.count
            jmp.opcode = .Jump(exitIndex)
            split.opcode = .Split(leftIndex, rightIndex)
        case let .And(left, right):
            //      split L1, L2
            //  L1: codes for e1
            //  L2: codes for e2
            let split = Instruction<T>(.Any)
            i.append(split)
            let leftIndex = i.count
            emit(left, instructions: &i)
            let rightIndex = i.count
            emit(right, instructions: &i)
            split.opcode = .Split(leftIndex, rightIndex)
            
        }
    }
}


private struct Engine<T: Equatable> {
    static func recursive(instructions i: [Instruction<T>], index: Int, input: [T], inout capture: [Int: [T]]) -> Bool {
        let inst = i[index]
        switch inst.opcode {
            
        case .Any:
            if input.isEmpty {
                return false
            }
            return recursive(instructions: i, index: index + 1, input: Array(input.dropFirst()), capture: &capture)
        case let .Literal(predicate):
            guard let char = input.first else {
                return false
            }
            guard predicate(char) else {
                return false
            }
            return recursive(instructions: i, index: index + 1, input: Array(input.dropFirst()), capture: &capture)
        case let .Sequence(predicate):
            guard predicate(input) else {
                return false
            }
            return recursive(instructions: i, index: index + 1, input: [], capture: &capture)
        case .Match:
            return true
        case let .Jump(to):
            return recursive(instructions: i, index: to, input: input, capture: &capture)
        case let .Split(left, right):
            if recursive(instructions: i, index: left, input: input, capture: &capture) {
                return true
            }
            return recursive(instructions: i, index: right, input: input, capture: &capture)
        case let .Save(n):
            let old = capture[n]
            capture[n] = input
            if recursive(instructions: i, index: index + 1, input: input, capture: &capture) {
                return true
            }
            capture[n] = old
            return false
        }
    }
    
    static func recursive(instructions i: [Instruction<T>], index: Int, input: [T]) -> [Range<Int>]? {
        var capture: [Int: [T]] = [:]
        guard recursive(instructions: i, index: index, input: input, capture: &capture) else {
            return nil
        }
        guard let maxIndex = capture.keys.maxElement() else {
            assertionFailure("capture is empty")
            return nil
        }
        var result: [Range<Int>] = []
        for i in 0.stride(to: maxIndex, by: 2) {
            guard let c1 = capture[i], c2 = capture[i+1] else {
                assertionFailure("expected captured element for index \(i) and \(i+1)")
                return nil
            }
            result.append(input.count - c1.count..<input.count - c2.count)
            
        }
        return result
    }
}

extension Instruction: CustomStringConvertible {
    private var description: String {
        return "\(opcode)"
    }
}