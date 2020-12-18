//
//  Protobuf.swift
//  Listuff
//
//  Created by MigMit on 18.12.2020.
//

import Foundation

enum ProtobufValue {
    case varint(value: UInt, svalue: Int)
    case fixed64(int: UInt64, float: Double)
    case lengthLimited(value: [(UInt, ProtobufValue)]?, string: String?, hex: Data)
    case fixed32(int: UInt32, float: Float)
    static func readVarint(data: Data, offset: Int, maxLen: Int) -> (UInt, Int)? {
        var multiple: UInt = 1
        var summand: UInt = 0
        var currentOffset = offset
        while (currentOffset < maxLen) {
            let byte = data[currentOffset]
            if (byte < 128) {
                return (UInt(byte) * multiple + summand, currentOffset + 1)
            } else {
                summand += UInt(byte - 128) &* multiple
                multiple <<= 7
                currentOffset += 1
            }
        }
        return nil
    }
    static func readUInt32(data: Data, offset: Int) -> UInt32 {
        var result: UInt32 = 0
        var multiple: UInt32 = 1
        for pos in 0..<4 {
            result += UInt32(data[offset+pos]) * multiple
            multiple <<= 8
        }
        return result
    }
    static func readUInt64(data: Data, offset: Int) -> UInt64 {
        var result: UInt64 = 0
        var multiple: UInt64 = 1
        for pos in 0..<8 {
            result += UInt64(data[offset+pos]) * multiple
            multiple <<= 8
        }
        return result
    }
    static func from(data: Data, offset: Int, maxLen: Int) -> (UInt, ProtobufValue, Int)? {
        if let (header, bodyOffset) = readVarint(data: data, offset: offset, maxLen: maxLen) {
            let (fieldNum, wireType) = header.quotientAndRemainder(dividingBy: 8)
            switch(wireType) {
            case 0:
                if let (value, newOffset) = readVarint(data: data, offset: bodyOffset, maxLen: maxLen) {
                    return (fieldNum, .varint(value: value, svalue: Int(bitPattern: value)), newOffset)
                } else {
                    return nil
                }
            case 1:
                guard bodyOffset + 8 <= maxLen else {return nil}
                let uint64 = readUInt64(data: data, offset: bodyOffset)
                return (fieldNum, .fixed64(int: uint64, float: Double(bitPattern: uint64)), bodyOffset + 8)
            case 2:
                if let (totalLength, messagesOffset) = readVarint(data: data, offset: bodyOffset, maxLen: maxLen) {
                    let messagesEnd = messagesOffset + Int(totalLength)
                    if messagesEnd > maxLen {
                        return nil
                    } else {
                        let dataSlice = data[messagesOffset..<messagesEnd]
                        let messages = arrayFrom(data: data, offset: messagesOffset, maxLen: messagesEnd)
                        return (fieldNum, .lengthLimited(value: messages, string: String(data: dataSlice, encoding: .utf8), hex: dataSlice), messagesEnd)
                    }
                } else {
                    return nil
                }
            case 5:
                guard bodyOffset + 4 <= maxLen else {return nil}
                let uint32 = readUInt32(data: data, offset: bodyOffset)
                return (fieldNum, .fixed32(int: uint32, float: Float(bitPattern: uint32)), bodyOffset + 4)
            default:
                return nil
            }
        } else {
            return nil
        }
    }
    static func arrayFrom(data: Data, offset: Int, maxLen: Int) -> [(UInt, ProtobufValue)]? {
        var messages: [(UInt, ProtobufValue)] = []
        var nextOffset = offset
        while nextOffset < maxLen {
            if let (fieldNum, message, newOffset) = from(data: data, offset: nextOffset, maxLen: maxLen) {
                messages.append((fieldNum, message))
                nextOffset = newOffset
            } else {
                return nil
            }
        }
        return messages
    }
    static func arrayFrom(data: Data) -> [(UInt, ProtobufValue)]? {
        return arrayFrom(data: data, offset: 0, maxLen: data.count)
    }
    func normalize() -> NormalizedProtobufValue {
        switch(self) {
        case .varint(let value, let svalue): return .varint(value: value, svalue: svalue)
        case .fixed64(let int, let float): return .fixed64(int: int, float: float)
        case .lengthLimited(let value, let string, let hex): return .lengthLimited(value: value.map{ProtobufValue.normalizeArray(array: $0)}, string: string, hex: hex)
        case .fixed32(let int, let float): return .fixed32(int: int, float: float)
        }
    }
    static func normalizeArray(array: [(UInt, ProtobufValue)]) -> [UInt: [NormalizedProtobufValue]] {
        var normalized: [UInt: [NormalizedProtobufValue]] = [:]
        for (k, pv) in array {
            normalized[k] = (normalized[k] ?? []) + [pv.normalize()]
        }
        return normalized
    }
}

enum NormalizedProtobufValue {
    case varint(value: UInt, svalue: Int)
    case fixed64(int: UInt64, float: Double)
    case lengthLimited(value: [UInt: [NormalizedProtobufValue]]?, string: String?, hex: Data)
    case fixed32(int: UInt32, float: Float)
    func getInt() -> Int? {if case .varint(_, let svalue) = self {return svalue} else {return nil}}
    func getUInt() -> UInt? {if case .varint(let value, _) = self {return value} else {return nil}}
    func getInt64() -> Int64? {if case .fixed64(let int, _) = self {return Int64(bitPattern: int)} else {return nil}}
    func getUInt64() -> UInt64? {if case .fixed64(let int, _) = self {return int} else {return nil}}
    func getDouble() -> Double? {if case .fixed64(_, let float) = self {return float} else {return nil}}
    func getInt32() -> Int32? {if case .fixed32(let int, _) = self {return Int32(bitPattern: int)} else {return nil}}
    func getUInt32() -> UInt32? {if case .fixed32(let int, _) = self {return int} else {return nil}}
    func getString() -> String? {if case .lengthLimited(_, let string, _) = self {return string} else {return nil}}
    func getBinaryData() -> Data? {if case .lengthLimited(_, _, let hex) = self {return hex} else {return nil}}
    func getField(_ field: UInt) -> [NormalizedProtobufValue]? {if case .lengthLimited(let value, _, _) = self {return value?[field]} else {return nil}}
}

class DecodedTable {
    let cells: [[String]]
    init?(source: NotesTable) {
        guard let top = source.records.first(where: {($0 as? NotesObject)?.objType == "com.apple.notes.ICTable"}) as? NotesObject else {return nil}
        guard let rows = (top.fields["crColumns"] as? NotesPositions)?.positions else {return nil}
        guard let columns = (top.fields["crRows"] as? NotesPositions)?.positions else {return nil}
        guard let cellColumns = (top.fields["cellColumns"] as? NotesDict)?.fields else {return nil}
        var full: [[String]] = []
        for row in rows {
            var current: [String] = []
            let rowContent: [Data:NotesRecord] = row.flatMap{(cellColumns[$0] as? NotesDict)?.fields} ?? [:]
            for column in columns {
                if let col = column,
                   let colContent = (rowContent[col] as? NotesCell)?.content {
                    current.append(colContent)
                } else {
                    current.append("")
                }
            }
            full.append(current)
        }
        cells = full
    }
}

class NotesTable {
    let fields: [String?]
    let types: [String?]
    let GUIDs: [Data?]
    let records: [NotesRecord?]
    init?(source: NormalizedProtobufValue) {
        guard let content = source.getField(2)?.first?.getField(3)?.first else {return nil}
        let fields = (content.getField(4) ?? []).map {$0.getString()}
        let types = (content.getField(5) ?? []).map {$0.getString()}
        let GUIDs = (content.getField(6) ?? []).map {$0.getBinaryData()}
        let records: [NotesRecord] = (content.getField(3) ?? []).map {record in
            if let object = record.getField(13)?.first {
                return NotesObject(protobuf: object)
            } else if let cell = record.getField(10)?.first {
                return NotesCell(protobuf: cell)
            } else if let dict = record.getField(6)?.first {
                return NotesDict(protobuf: dict)
            } else if let positions = record.getField(16)?.first {
                return NotesPositions(protobuf: positions)
            } else {
                return NotesRecord(protobuf: record)
            }
        }
        for record in records {
            if !record.fill(fields: fields, types: types, records: records) {
                return nil
            }
        }
        for record in records {
            if !record.finalize(GUIDs: GUIDs) {
                return nil
            }
        }
        self.fields = fields
        self.types = types
        self.GUIDs = GUIDs
        self.records = records
    }
}

protocol NotesField {}
extension Int: NotesField {}
extension String: NotesField {}

class NotesRecord: NotesField {
    let protobuf: NormalizedProtobufValue?
    init(protobuf: NormalizedProtobufValue?) {
        self.protobuf = protobuf
    }
    func fill(fields: [String?], types: [String?], records: [NotesRecord?]) -> Bool {return true}
    func finalize(GUIDs: [Data?]) -> Bool {return true}
}
class NotesObject: NotesRecord {
    var objType: String = ""
    var fields: [String: NotesField] = [:]
    func guid(GUIDs: [Data?]) -> Data? {
        if objType == "com.apple.CRDT.NSUUID", let uuidIndex = fields["UUIDIndex"] as? Int, uuidIndex >= 0, uuidIndex < GUIDs.count {
            return GUIDs[uuidIndex]
        } else {
            return nil
        }
    }
    override func fill(fields: [String?], types: [String?], records: [NotesRecord?]) -> Bool {
        guard let typeId = protobuf?.getField(1)?.first?.getInt(), typeId >= 0, typeId < types.count, let objType = types[typeId] else {return false}
        self.objType = objType
        let objFields = protobuf?.getField(3) ?? []
        for field in objFields {
            guard let nameId = field.getField(1)?.first?.getInt(), nameId >= 0, nameId < fields.count, let fieldName = fields[nameId], self.fields[fieldName] == nil else {return false}
            guard let value = field.getField(2)?.first else {return false}
            if let intValue = value.getField(2)?.first?.getInt() {
                self.fields[fieldName] = intValue
            } else if let stringValue = value.getField(4)?.first?.getString() {
                self.fields[fieldName] = stringValue
            } else if let objIndex = value.getField(6)?.first?.getInt(), objIndex >= 0, objIndex < records.count, let objValue = records[objIndex] {
                self.fields[fieldName] = objValue
            } else {
                return false
            }
        }
        return true
    }
    override func finalize(GUIDs: [Data?]) -> Bool {
        return true
    }
}
class NotesCell: NotesRecord {
    var content: String = ""
    override func fill(fields: [String?], types: [String?], records: [NotesRecord?]) -> Bool {
        if let content = protobuf?.getField(2)?.first?.getString() {
            self.content = content
            return true
        } else {
            return false
        }
    }
    override func finalize(GUIDs: [Data?]) -> Bool {
        return true
    }
}
class NotesDict: NotesRecord {
    var prefields: [(NotesRecord,NotesRecord)] = []
    var fields: [Data:NotesRecord] = [:]
    override func fill(fields: [String?], types: [String?], records: [NotesRecord?]) -> Bool {
        let items = protobuf?.getField(1) ?? []
        for item in items {
            guard let keyId = item.getField(1)?.first?.getField(6)?.first?.getInt(), keyId >= 0, keyId < records.count, let key = records[keyId] else {return false}
            guard let valueId = item.getField(2)?.first?.getField(6)?.first?.getInt(), valueId >= 0, valueId < records.count, let value = records[valueId] else {return false}
            prefields.append((key, value))
        }
        return true
    }
    override func finalize(GUIDs: [Data?]) -> Bool {
        self.fields = [:]
        for (key, value) in prefields {
            if let keyObj = key as? NotesObject, let guid = keyObj.guid(GUIDs: GUIDs) {
                guard self.fields[guid] == nil else {return false}
                self.fields[guid] = value
            }
        }
        return true
    }
}
class NotesPositions: NotesRecord {
    var positions: [Data?] = []
    var alivePreKeys: NotesDict? = nil
    var realPreKeys: NotesDict? = nil
    var posPreKeys: [Data?] = []
    override func fill(fields: [String?], types: [String?], records: [NotesRecord?]) -> Bool {
        guard let aliveKeysProto = protobuf?.getField(2)?.first else {return false}
        let aliveKeysDict = NotesDict(protobuf: aliveKeysProto)
        guard aliveKeysDict.fill(fields: fields, types: types, records: records) else {return false}
        self.alivePreKeys = aliveKeysDict
        guard let posContent = protobuf?.getField(1)?.first else {return false}
        guard let realPosDict = posContent.getField(2)?.first else {return false}
        realPreKeys = NotesDict(protobuf: realPosDict)
        guard realPreKeys?.fill(fields: fields, types: types, records: records) ?? false else {return false}
        guard let posOrder = posContent.getField(1)?.first?.getField(2) else {return false}
        var posItems: [Int:Data] = [:]
        for posItem in posOrder {
            guard let index = posItem.getField(1)?.first?.getInt(), posItems[index] == nil else {return false}
            guard let guid = posItem.getField(2)?.first?.getBinaryData() else {return false}
            posItems[index] = guid
        }
        let maxIndex = posItems.keys.max() ?? -1
        self.posPreKeys = []
        for index in 0...maxIndex {
            self.posPreKeys.append(posItems[index])
        }
        return true
    }
    override func finalize(GUIDs: [Data?]) -> Bool {
        guard self.alivePreKeys?.finalize(GUIDs: GUIDs) ?? false else {return false}
        guard self.realPreKeys?.finalize(GUIDs: GUIDs) ?? false else {return false}
        guard let alivePreKeys = self.alivePreKeys else {return false}
        guard let realPreKeys = self.realPreKeys else {return false}
        let aliveGUIDs = Set(alivePreKeys.fields.keys)
        let realKeys = realPreKeys.fields.mapValues{
            ($0 as? NotesObject)?.guid(GUIDs: GUIDs)
        }
        self.positions = []
        for pos in posPreKeys {
            if let position = pos, aliveGUIDs.contains(position), let realKey = realKeys[position] {
                self.positions.append(realKey)
            } else {
                self.positions.append(nil)
            }
        }
        return true
    }
}
