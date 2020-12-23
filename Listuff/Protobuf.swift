//
//  Protobuf.swift
//  Listuff
//
//  Created by MigMit on 18.12.2020.
//

import SwiftUI

class ProtoMessage {
    let value: Data
    lazy var parsed: [UInt: [ProtoValue]]? = {
        var result: [UInt: [ProtoValue]] = [:]
        var offset = value.startIndex
        while offset < value.endIndex {
            guard let (newOffset, fieldNum, protoVal) = ProtoValue.from(data: value, offset: offset) else {return nil}
            result[fieldNum] = (result[fieldNum] ?? []) + [protoVal]
            offset = newOffset
        }
        return result
    }()
    init(value: Data) {
        self.value = value
    }
}

enum ProtoValue {
    case varint(value: UInt)
    case fixed64(value: UInt64)
    case lengthLimited(value: ProtoMessage)
    case fixed32(value: UInt32)
    func getInt() -> Int? {if case .varint(let value) = self {return Int(bitPattern: value)} else {return nil}}
    func getUInt() -> UInt? {if case .varint(let value) = self {return value} else {return nil}}
    func getInt64() -> Int64? {if case .fixed64(let value) = self {return Int64(bitPattern: value)} else {return nil}}
    func getUInt64() -> UInt64? {if case .fixed64(let value) = self {return value} else {return nil}}
    func getDouble() -> Double? {if case .fixed64(let value) = self {return Double(bitPattern: value)} else {return nil}}
    func getInt32() -> Int32? {if case .fixed32(let value) = self {return Int32(bitPattern: value)} else {return nil}}
    func getUInt32() -> UInt32? {if case .fixed32(let value) = self {return value} else {return nil}}
    func getFloat() -> Float? {if case .fixed32(let value) = self {return Float(bitPattern: value)} else {return nil}}
    func getString() -> String? {if case .lengthLimited(let value) = self {return String(bytes: value.value, encoding: .utf8)} else {return nil}}
    func getBinaryData() -> Data? {if case .lengthLimited(let value) = self {return value.value} else {return nil}}
    func getField(_ field: UInt) -> [ProtoValue]? {if case .lengthLimited(let value) = self {return value.parsed?[field]} else {return nil}}
    
    static func from(data: Data, offset: Int) -> (Int, UInt, ProtoValue)? {
        guard let (header, bodyOffset) = readVarint(data: data, offset: offset) else {return nil}
        let (fieldNum, wireType) = header.quotientAndRemainder(dividingBy: 8)
        switch(wireType) {
        case 0:
            guard let (value, newOffset) = readVarint(data: data, offset: bodyOffset) else {return nil}
            return (newOffset, fieldNum, .varint(value: value))
        case 1:
            guard bodyOffset + 8 <= data.endIndex else {return nil}
            let value = readUInt64(data: data, offset: bodyOffset)
            return (bodyOffset + 8, fieldNum, .fixed64(value: value))
        case 2:
            guard let (totalLength, messagesOffset) = readVarint(data: data, offset: bodyOffset) else {return nil}
            let messagesEnd = messagesOffset + Int(totalLength)
            guard messagesEnd <= data.endIndex else {return nil}
            return (messagesEnd, fieldNum, .lengthLimited(value: ProtoMessage(value: data[messagesOffset..<messagesEnd])))
        case 5:
            guard bodyOffset + 4 <= data.endIndex else {return nil}
            let value = readUInt32(data: data, offset: bodyOffset)
            return (bodyOffset + 4, fieldNum, .fixed32(value: value))
        default:
            return nil
        }
    }
    
    static func readVarint(data: Data, offset: Int) -> (UInt, Int)? {
        var multiple: UInt = 1
        var summand: UInt = 0
        var currentOffset = offset
        while (currentOffset < data.endIndex) {
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
}

class Note {
    let content: String
    let chunks: [NoteChunk]
    init?(source: ProtoValue, attachments: NSDictionary?) {
        guard let content = source.getField(2)?.first?.getString() else {return nil}
        self.content = content
        let chunkInfo = source.getField(5)?.map{NoteChunk(source: $0, attachments: attachments)} ?? []
        var chunks: [NoteChunk] = []
        for chunk in chunkInfo {
            guard let c = chunk else {return nil}
            chunks.append(c)
        }
        self.chunks = chunks
    }
}

class NoteChunk {
    let length: Int
    let textSize: Float?
    let textStyle: NoteTextStyle
    let paragraphStyle: ParagraphStyle?
    let baselineOffset: Int
    let linkUrl: String?
    let color: Color?
    let attachment: NoteAttachment?
    init?(source: ProtoValue, attachments: NSDictionary?) {
        if let length = source.getField(1)?.first?.getInt() {
            if let ps = source.getField(2)?.first {
                var paragraphType = ParagraphType.normal
                var alignment = Alignment.left
                var writingDirection = WritingDirection.ltr
                var listDepth: UInt = 0
                if let pt = ps.getField(1)?.first?.getUInt() {
                    switch(pt) {
                    case 0: paragraphType = .title
                    case 1: paragraphType = .heading
                    case 2: paragraphType = .subheading
                    case 0x64: paragraphType = .bullet
                    case 0x65: paragraphType = .dash
                    case 0x66: paragraphType = .number
                    case 0x67:
                        let checked = ps.getField(5)?.first?.getField(2)?.first?.getUInt()
                        paragraphType = .check(isChecked: (checked ?? 0) != 0)
                    default: break
                    }
                }
                if let al = ps.getField(2)?.first?.getUInt() {
                    switch(al) {
                    case 0: alignment = .left
                    case 1: alignment = .center
                    case 2: alignment = .right
                    case 3: alignment = .justify
                    default: break
                    }
                }
                if let wd = ps.getField(3)?.first?.getUInt() {
                    switch(wd) {
                    case 0: writingDirection = .ltr
                    case 1: writingDirection = .dflt
                    case 2: writingDirection = .rtl
                    default: break
                    }
                }
                if let ld = ps.getField(4)?.first?.getUInt() {
                    listDepth = ld
                }
                self.paragraphStyle = ParagraphStyle(paragraphType: paragraphType, alignment: alignment, writingDirection: writingDirection, listDepth: listDepth)
            } else {
                self.paragraphStyle = nil
            }
            self.length = length
            let textSize = source.getField(3)?.first?.getField(2)?.first?.getFloat()
            self.textSize = textSize
            var textStyle: NoteTextStyle = []
            if let ts = source.getField(5)?.first?.getUInt() {
                if ts & 0x1 != 0 {textStyle.insert(.bold)}
                if ts & 0x2 != 0 {textStyle.insert(.italic)}
            }
            if let und = source.getField(6)?.first?.getUInt(), und != 0 {
                textStyle.insert(.underlined)
            }
            if let stt = source.getField(7)?.first?.getUInt(), stt != 0 {
                textStyle.insert(.strikethrough)
            }
            self.textStyle = textStyle
            if let bo = source.getField(8)?.first?.getUInt() {
                self.baselineOffset = Int(bitPattern: bo)
            } else {
                self.baselineOffset = 0
            }
            self.linkUrl = source.getField(9)?.first?.getString()
            if let clr = source.getField(10)?.first,
               let red = clr.getField(1)?.first?.getFloat(),
               let green = clr.getField(2)?.first?.getFloat(),
               let blue = clr.getField(3)?.first?.getFloat(),
               let alpha = clr.getField(4)?.first?.getFloat() {
                self.color = Color(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
            } else {
                self.color = nil
            }
            if let attachment = source.getField(12)?.first,
               let guid = attachment.getField(1)?.first?.getString(),
               let atType = attachment.getField(2)?.first?.getString() {
                switch(atType) {
                case "com.apple.notes.table":
                    if let attachmentData = attachments?[guid + "_mergeableData"] as? Data,
                       let unarchived = gunzipFile(gzipped: attachmentData),
                       let notesTable = NotesTable(source: ProtoValue.lengthLimited(value: ProtoMessage(value: unarchived))),
                       let decoded = DecodedTable(source: notesTable) {
                        self.attachment = .table(table: transpose(source: decoded.cells))
                    } else {
                        self.attachment = nil
                    }
                default:
                    self.attachment = nil
                }
            } else {
                self.attachment = nil
            }
        } else {
            return nil
        }
    }
}

struct GzipFlags: OptionSet {
    let rawValue: UInt8
    static let text = GzipFlags(rawValue: 1 << 0)
    static let hcrc = GzipFlags(rawValue: 1 << 1)
    static let extra = GzipFlags(rawValue: 1 << 2)
    static let name = GzipFlags(rawValue: 1 << 3)
    static let comment = GzipFlags(rawValue: 1 << 4)
}

func gunzipFile(gzipped: Data) -> Data? {
    var dataOffset = gzipped.startIndex + 10
    let dataEnd = gzipped.endIndex - 8
    guard dataOffset <= dataEnd else {return nil}
    let flags = GzipFlags(rawValue: gzipped[3])
    if flags.contains(.extra) {
        let xlen = Int(gzipped[dataOffset]) + Int(gzipped[dataOffset+1]) * 256
        dataOffset += xlen + 2
        guard dataOffset <= dataEnd else {return nil}
    }
    if flags.contains(.name) {
        while gzipped[dataOffset] != 0 && dataOffset < dataEnd {dataOffset += 1}
        dataOffset += 1
        guard dataOffset <= dataEnd else {return nil}
    }
    if flags.contains(.comment) {
        while gzipped[dataOffset] != 0 && dataOffset < dataEnd {dataOffset += 1}
        dataOffset += 1
        guard dataOffset <= dataEnd else {return nil}
    }
    return (try? (gzipped[dataOffset..<dataEnd] as NSData).decompressed(using: .zlib)) as Data?
}

func transpose<T>(source: [[T]]) -> [[T]] {
    var result: [[T]] = []
    if !source.isEmpty {
        result = source[0].map{[$0]}
        for row in source[1..<source.count] {
            var temp: [[T]] = []
            for (resultRow, elt) in zip(result, row) {
                temp.append(resultRow + [elt])
            }
            result = temp
        }
    }
    return result
}

struct NoteTextStyle: OptionSet {
    let rawValue: UInt8
    static let bold = NoteTextStyle(rawValue: 1 << 0)
    static let italic = NoteTextStyle(rawValue: 1 << 1)
    static let underlined = NoteTextStyle(rawValue: 1 << 2)
    static let strikethrough = NoteTextStyle(rawValue: 1 << 3)
}
struct ParagraphStyle {
    let paragraphType: ParagraphType
    let alignment: Alignment
    let writingDirection: WritingDirection
    let listDepth: UInt
}
enum ParagraphType {
    case title
    case heading
    case subheading
    case normal
    case bullet
    case dash
    case number
    case check(isChecked: Bool)
}
enum Alignment {
    case left
    case center
    case right
    case justify
}
enum WritingDirection {
    case ltr
    case rtl
    case dflt
}
enum NoteAttachment {
    case table(table: [[Note?]])
}

class DecodedTable {
    let cells: [[Note?]]
    init?(source: NotesTable) {
        guard let top = source.records.first(where: {($0 as? NotesObject)?.objType == "com.apple.notes.ICTable"}) as? NotesObject else {return nil}
        guard let rows = (top.fields["crColumns"] as? NotesPositions)?.positions else {return nil}
        guard let columns = (top.fields["crRows"] as? NotesPositions)?.positions else {return nil}
        guard let cellColumns = (top.fields["cellColumns"] as? NotesDict)?.fields else {return nil}
        var full: [[Note?]] = []
        for row in rows {
            var current: [Note?] = []
            let rowContent: [Data:NotesRecord] = row.flatMap{(cellColumns[$0] as? NotesDict)?.fields} ?? [:]
            for column in columns {
                if let col = column,
                   let colContent = (rowContent[col] as? NotesCell)?.content {
                    current.append(colContent)
                } else {
                    current.append(nil)
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
    init?(source: ProtoValue) {
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
    let protobuf: ProtoValue?
    init(protobuf: ProtoValue?) {
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
    var content: Note? = nil
    override func fill(fields: [String?], types: [String?], records: [NotesRecord?]) -> Bool {
        self.content = protobuf.flatMap{Note(source: $0, attachments: nil)}
        return true
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
