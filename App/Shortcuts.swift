import Foundation
import AppIntents
import UniformTypeIdentifiers

struct QueueImageIntent: AppIntent {
    static var title: LocalizedStringResource = "Enviar imagem para Foteka"
    static var description = IntentDescription("Coloca uma imagem na fila local para ser classificada e organizada no Fotos quando o app for aberto.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Imagem ou arquivo", description: "Imagem do Fotos, Safari ou Arquivos")
    var image: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Enviar \(\.$image) para Foteka")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let fileExtension = image.type?.preferredFilenameExtension
            ?? URL(fileURLWithPath: image.filename).pathExtension.lowercased()
        let chosenExtension = fileExtension.isEmpty ? "jpeg" : fileExtension
        try InboxFileStore.enqueue(data: image.data, fileExtension: chosenExtension)
        return .result(dialog: "Imagem recebida. Abra Foteka para importar e classificar.")
    }
}

struct OrgaIAShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: QueueImageIntent(),
                    phrases: ["Enviar imagem para \(.applicationName)"],
                    shortTitle: "Organizar imagem",
                    systemImageName: "photo.badge.plus")
    }
}
