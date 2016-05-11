//
//  re1.swift
//  re1
//
//  Created by Sash Zats on 4/29/16.
//  Copyright © 2016 Sash Zats. All rights reserved.
//



public indirect enum Regexp<T: Equatable> {
    case Paren(Regexp, n: Int)
    case Star(Regexp, greedy: Bool)
    case Dot
    case Cat(Regexp, Regexp)
    case Literal(T -> Bool)
    case SequenceLiteral([T] -> Bool)
    case Plus(Regexp, greedy: Bool)
    case Quest(Regexp, greedy: Bool)
    case Alt(Regexp, Regexp)
    case And(Regexp, Regexp)
    
    public static func literal(value: T) -> Regexp {
        return .Literal({ $0 ==  value})
    }
    
    private func preprocessed() -> Regexp {
        let r: Regexp = .Paren(self, n: 0)
        let dotStar: Regexp = .Star(.Dot, greedy: false)
        return .Cat(dotStar, r)
    }
}

public extension Regexp {
    public func match(input: [T]) -> [Range<Int>] {
        let re = self//.preprocessed()
        let instructions = Emitter.emit(re)
        guard let capture = Engine.recursive(instructions: instructions, index: 0, input: input) else {
            fatalError()
        }
        return capture
    }
}


private enum Opcode<T: Equatable> {
    case SequenceLiteral([T] -> Bool)
    case Char(T -> Bool)
    case Match
    case Jmp(Int)
    case Split(Int, Int)
    case Any
    case Save(Int)
}

private class Inst<T: Equatable> {
    var opcode: Opcode<T>
    
    init(_ opcode: Opcode<T>) {
        self.opcode = opcode
    }
}

private struct Emitter<T: Equatable> {
    static func emit(r: Regexp<T>) -> [Inst<T>] {
        var instructions: [Inst<T>] = []
        emit(r, instructions: &instructions)
        instructions.append(Inst(.Match))
        return instructions
    }
    
    static func emit(r: Regexp<T>, inout instructions i: [Inst<T>]) {
        switch r {
        case let .Cat(left, right):
            emit(left, instructions: &i)
            emit(right, instructions: &i)
        case .Dot:
            let pc = Inst<T>(.Any)
            i.append(pc)
        case let .Star(r, greedy):
            // since we don't have instruction split should point to yet, we will insert a placeholder and remember the index
            let split = Inst<T>(.Any)
            let splitIndex = i.count
            i.append(split)
            emit(r, instructions: &i)
            let jmp = Inst<T>(.Jmp(splitIndex))
            let jmpIndex = i.count
            split.opcode = .Split(splitIndex + 1, jmpIndex + 1)
            i.append(jmp)
            if !greedy {
                split.opcode = .Split(jmpIndex + 1, splitIndex + 1)
            }
        case let .Paren(r, n):
            let pc = Inst<T>(.Save(2 * n))
            i.append(pc)
            emit(r, instructions: &i)
            let pc2 = Inst<T>(.Save(2 * n + 1))
            i.append(pc2)
        case let .SequenceLiteral(predicate):
            let pc = Inst(.SequenceLiteral(predicate))
            i.append(pc)
        case let .Literal(predicate):
            let pc = Inst(.Char(predicate))
            i.append(pc)
        case let .Plus(regexp, greedy):
            let index = i.count
            emit(regexp, instructions: &i)
            let splitIndex = i.count
            let split = Inst<T>(.Split(index, splitIndex + 1))
            i.append(split)
            if !greedy {
                split.opcode = .Split(splitIndex + 1, index)
            }
        case let .Quest(regexp, greedy):
            //      split L1, L2
            //  L1: codes for e1
            //  L2:
            let split = Inst<T>(.Any)
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
            let split = Inst<T>(.Any)
            i.append(split)
            let leftIndex = i.count
            emit(left, instructions: &i)
            let jmp = Inst<T>(.Any)
            i.append(jmp)
            let rightIndex = i.count
            emit(right, instructions: &i)
            let exitIndex = i.count
            jmp.opcode = .Jmp(exitIndex)
            split.opcode = .Split(leftIndex, rightIndex)
        case let .And(left, right):
            //      split L1, L2
            //  L1: codes for e1
            //  L2: codes for e2
            let split = Inst<T>(.Any)
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
    static func recursive(instructions i: [Inst<T>], index: Int, input: [T], inout capture: [Int: [T]]) -> Bool {
        let inst = i[index]
        switch inst.opcode {
            
        case .Any:
            if input.isEmpty {
                return false
            }
            return recursive(instructions: i, index: index + 1, input: Array(input.dropFirst()), capture: &capture)
        case let .Char(value):
            guard let char = input.first else {
                return false
            }
            guard value(char) else {
                return false
            }
            return recursive(instructions: i, index: index + 1, input: Array(input.dropFirst()), capture: &capture)
        case let .SequenceLiteral(predicate):
            guard predicate(input) else {
                return false
            }
            return recursive(instructions: i, index: index + 1, input: [], capture: &capture)
        case .Match:
//            assert(index == input.count)
            return true
        case let .Jmp(to):
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
    
    static func recursive(instructions i: [Inst<T>], index: Int, input: [T]) -> [Range<Int>]? {
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

extension Inst: CustomStringConvertible {
    private var description: String {
        return "\(opcode)"
    }
}