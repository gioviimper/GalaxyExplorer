import Foundation

// Keep each media record's description, image and attribution together.
nonisolated enum NASAPlanetContentMapper {
    static func cards(from data: Data, planetID: String) throws -> [PlanetCardContent] {
        let response = try JSONDecoder().decode(NASAImageSearchResponse.self, from: data)
        var seenIDs = Set<String>()
        var seenTitles = Set<String>()
        let items = response.collection.items.compactMap { item -> PlanetCardContent? in
            guard let metadata = item.data.first else { return nil }
            let title = clean(metadata.title)
            guard !title.isEmpty, !metadata.nasaID.isEmpty, seenIDs.insert(metadata.nasaID).inserted,
                seenTitles.insert(title.lowercased()).inserted
            else { return nil }
            let description = clean(metadata.description ?? "")
            let credit = (metadata.secondaryCreator ?? metadata.center).map(clean).flatMap {
                $0.isEmpty ? nil : $0
            }
            let links = (item.links ?? []).filter { $0.render == "image" || $0.rel == "preview" }
            let preview =
                links.first { $0.href.contains("~small") }
                ?? links.first { $0.href.contains("~thumb") } ?? links.first
            var source = URLComponents(string: "https://images.nasa.gov")!
            source.path = "/details/" + metadata.nasaID
            return PlanetCardContent(
                id: "", nasaID: metadata.nasaID, title: title,
                summary: clip(description, limit: 90), detail: description.isEmpty ? nil : description,
                imageURL: preview.flatMap { trustedImageURL($0.href) }, sourceURL: source.url, credit: credit)
        }
        return PlanetCardContent.emptySlots(for: planetID).enumerated().map { index, slot in
            guard items.indices.contains(index) else { return slot }
            let item = items[index]
            return PlanetCardContent(
                id: slot.id, nasaID: item.nasaID, title: item.title,
                summary: item.summary, detail: item.detail, imageURL: item.imageURL,
                sourceURL: item.sourceURL, credit: item.credit)
        }
    }

    static func clean(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (entity, replacement) in [
            ("&nbsp;", " "), ("&amp;", "&"), ("&quot;", "\""),
            ("&#39;", "'"), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"),
        ] {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func clip(_ text: String, limit: Int) -> String? {
        guard !text.isEmpty else { return nil }
        return text.count <= limit
            ? text : String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
    static func trustedImageURL(_ string: String) -> URL? {
        guard let url = URL(string: string), url.scheme == "https", let host = url.host,
            host == "nasa.gov" || host.hasSuffix(".nasa.gov")
        else { return nil }
        return url
    }
}
