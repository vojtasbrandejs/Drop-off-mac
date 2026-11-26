import AppKit
import Foundation

@MainActor
final class ShelfModel {
    private(set) var items: [ShelfItem] = []
    private(set) var promisedFilesImportState = PromisedFilesImportState()
    var onChange: (() -> Void)?

    private let thumbnailProvider: ThumbnailProviding
    private let transientFileStore: ShelfTransientFileStore
    private var pendingPromisedFilesByImport: [UUID: Int] = [:]

    init(
        thumbnailProvider: ThumbnailProviding = ThumbnailProvider(),
        transientFileStore: ShelfTransientFileStore = ShelfTransientFileStore()
    ) {
        self.thumbnailProvider = thumbnailProvider
        self.transientFileStore = transientFileStore
    }

    @discardableResult
    func addDropped(urls: [URL]) throws -> Int {
        let fileURLs = urls.filter(\.isFileURL)
        let links = urls.filter { !$0.isFileURL }
        let preservedURLs = try transientFileStore.preserveTransientURLs(fileURLs)
        return add(urls: preservedURLs + links)
    }

    @discardableResult
    func addDroppedMedia(_ representations: [DroppedMediaRepresentation]) throws -> Int {
        guard !representations.isEmpty else { return 0 }
        let destination = try transientFileStore.makePromisedFilesDestination()
        var materializedURLs: [URL] = []

        do {
            for representation in representations {
                let url = transientFileStore.uniqueDestination(
                    named: representation.fileName,
                    in: destination
                )
                try representation.data.write(to: url, options: .atomic)
                materializedURLs.append(url)
            }
            return add(urls: materializedURLs)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    func beginPromisedFilesImport(expectedFileCount: Int = 0) throws -> ShelfPromisedFilesImport {
        let promisedImport = ShelfPromisedFilesImport(
            destination: try transientFileStore.makePromisedFilesDestination(),
            id: UUID()
        )
        pendingPromisedFilesByImport[promisedImport.id] = max(expectedFileCount, 0)
        let previous = promisedFilesImportState
        promisedFilesImportState.failureMessage = nil
        updatePendingPromisedFileCount()
        if previous != promisedFilesImportState {
            onChange?()
        }
        return promisedImport
    }

    func setPromisedFilesImportExpectedCount(_ count: Int, importID: UUID) {
        guard pendingPromisedFilesByImport[importID] != nil else { return }
        pendingPromisedFilesByImport[importID] = count > 0 ? count : nil
        updatePendingPromisedFileCount()
        onChange?()
    }

    func completePromisedFile(
        at url: URL,
        error: Error?,
        importID: UUID
    ) {
        guard let pending = pendingPromisedFilesByImport[importID], pending > 0 else { return }
        pendingPromisedFilesByImport[importID] = pending > 1 ? pending - 1 : nil
        updatePendingPromisedFileCount()
        if let error {
            promisedFilesImportState.failureMessage = error.localizedDescription
        } else {
            let correctedURL = (try? transientFileStore.correctMediaFilenameIfNeeded(at: url))
                ?? url
            if add(urls: [correctedURL]) > 0 { return }
        }
        onChange?()
    }

    func reportPromisedFilesImportFailure(_ error: Error) {
        promisedFilesImportState.failureMessage = error.localizedDescription
        onChange?()
    }

    private func updatePendingPromisedFileCount() {
        promisedFilesImportState.pendingFileCount = pendingPromisedFilesByImport.values.reduce(0, +)
    }

    @discardableResult
    func add(urls: [URL]) -> Int {
        var knownKeys = Set(items.map(\.identityKey))
        var addedItems: [ShelfItem] = []

        for url in urls {
            guard let item = ShelfItem(url: url), !knownKeys.contains(item.identityKey) else {
                continue
            }
            knownKeys.insert(item.identityKey)
            items.append(item)
            addedItems.append(item)
        }

        guard !addedItems.isEmpty else { return 0 }
        onChange?()

        for item in addedItems where item.kind == .file {
            thumbnailProvider.requestThumbnail(for: item.currentURL) { [weak self, weak item] image in
                guard let self, let item, self.items.contains(where: { $0 === item }) else { return }
                item.thumbnail = image
                self.onChange?()
            }
        }
        return addedItems.count
    }

    func clear() {
        let hadVisibleState = !items.isEmpty || promisedFilesImportState != PromisedFilesImportState()
        pendingPromisedFilesByImport.removeAll()
        promisedFilesImportState = PromisedFilesImportState()
        items.removeAll()
        transientFileStore.clear()
        if hadVisibleState {
            onChange?()
        }
    }

    func removeUnavailable() {
        let originalCount = items.count
        items.removeAll { !$0.isAvailable }
        if items.count != originalCount {
            onChange?()
        }
    }

    @discardableResult
    func refreshAvailability() -> Bool {
        let previous = items.map(\.isAvailable)
        for item in items {
            item.resolveCurrentURL()
        }
        let changed = previous != items.map(\.isAvailable)
        if changed {
            onChange?()
        }
        return changed
    }

    func availableItems() -> [ShelfItem] {
        refreshAvailability()
        return items.filter(\.isAvailable)
    }
}

struct ShelfPromisedFilesImport {
    let destination: URL
    let id: UUID
}

struct PromisedFilesImportState: Equatable {
    var pendingFileCount = 0
    var failureMessage: String?

    var isImporting: Bool { pendingFileCount > 0 }
}
