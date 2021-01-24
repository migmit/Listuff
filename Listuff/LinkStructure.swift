//
//  LinkStructure.swift
//  Listuff
//
//  Created by MigMit on 15.01.2021.
//

import Foundation

class LinkStructure {
    typealias Doc = Structure<DocData>
    var livingLinks: Partition<UUID?, ()> = Partition(parent: ())
    var brokenLinks: Partition<UUID?, ()> = Partition(parent: ())
    var linkTargets: [UUID: Doc.Line] = [:]
    var brokenLinkSources: [UUID: Set<IdHolder<Partition<UUID?, ()>.Node>>] = [:]
    //    var previews: [UUID: String] = [:]
}

class LinkAppender {
    typealias Doc = Structure<DocData>
    var lines: [String: Doc.Line] = [:]
    var links: [(NSRange, String)] = []
    
    func appendLine(shift: Int, linkId: String?, nsLinks: [(NSRange, String)], line: Doc.Line) {
        if let lid = linkId {
            lines[lid] = line
        }
        for (range, lid) in nsLinks {
            links.append((range.shift(by: shift), lid))
        }
    }
    func processLinks(fullSize: Int, linkStructure: LinkStructure) {
        links.sort{lhs, rhs in
            lhs.0.location < rhs.0.location ||
                (lhs.0.location == rhs.0.location && lhs.0.length > rhs.0.length)
        }
        var lastLink: (NSRange, String)? = nil
        var fixedLinks: [(NSRange, String)] = []
        for (range, id) in links {
            if let (lastRange, lastId) = lastLink {
                if range.location <= lastRange.location {continue}
                fixedLinks.append((NSMakeRange(lastRange.location, min(lastRange.length, range.location - lastRange.location)), lastId))
            }
            lastLink = (range, id)
        }
        if let last = lastLink {
            fixedLinks.append(last)
        }
        var mentionedUUIDs: [String: UUID] = [:]
        for (_, id) in fixedLinks {
            if mentionedUUIDs[id] == nil {
                let uuid = UUID()
                mentionedUUIDs[id] = uuid
                if let line = lines[id] {
                    line.content?.guid = uuid
                    linkStructure.linkTargets[uuid] = line
                }
            }
        }
        var lastLiveLocation = 0
        var lastBrokenLocation = 0
        for (range, id) in fixedLinks {
            let uuid = mentionedUUIDs[id]!
            if let line = lines[id] {
                if range.location > lastLiveLocation {
                    _ = linkStructure.livingLinks.insert(value: nil, length: range.location - lastLiveLocation, dir: .Left)
                }
                let livingNode = linkStructure.livingLinks.insert(value: uuid, length: range.length, dir: .Left).0
                line.content?.backlinks.insert(IdHolder(value: livingNode))
                lastLiveLocation = range.end
            } else {
                if range.location > lastBrokenLocation {
                    _ = linkStructure.brokenLinks.insert(value: nil, length: range.location - lastBrokenLocation, dir: .Left)
                }
                let brokenNode = linkStructure.brokenLinks.insert(value: uuid, length: range.length, dir: .Left).0
                var fullSet = linkStructure.brokenLinkSources[uuid] ?? Set()
                fullSet.insert(IdHolder(value: brokenNode))
                linkStructure.brokenLinkSources[uuid] = fullSet
                lastBrokenLocation = range.end
            }
        }
        if fullSize > lastLiveLocation {
            _ = linkStructure.livingLinks.insert(value: nil, length: fullSize - lastLiveLocation, dir: .Left)
        }
        if fullSize > lastBrokenLocation {
            _ = linkStructure.brokenLinks.insert(value: nil, length: fullSize - lastBrokenLocation, dir: .Left)
        }
    }
}
