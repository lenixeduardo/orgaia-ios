import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var model = LibraryViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            LibraryTab(model: model, store: model.store)
                .tabItem { Label("Galeria", systemImage: "photo.on.rectangle") }
            ReviewTab(model: model, store: model.store)
                .tabItem { Label("Revisão", systemImage: "checkmark.circle") }
            RulesTab(store: model.store)
                .tabItem { Label("Regras", systemImage: "slider.horizontal.3") }
            SettingsTab(model: model, store: model.store)
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
        .task { await model.onActive() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await model.onActive() } }
        }
        .alert("Foteka", isPresented: Binding(get: { model.errorMessage != nil },
                                               set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

struct LibraryTab: View {
    @ObservedObject var model: LibraryViewModel
    @ObservedObject var store: CatalogStore
    @State private var scanSelection = 100

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if !PhotoLibraryService.shared.canRead() { accessCard }
                    else {
                        CollectionHero(photoID: store.ordered.first?.id)
                        HStack {
                            Text("Categorias")
                                .font(.title3.bold())
                            Spacer()
                            Text("Fotos analisadas")
                                .font(.caption)
                                .foregroundStyle(OrgaColors.secondary)
                        }
                        CollectionGrid(model: model, store: store)
                        HStack(spacing: 10) {
                            Picker("Quantidade", selection: $scanSelection) {
                                Text("100").tag(100)
                                Text("500").tag(500)
                                Text("2000").tag(2000)
                                Text("Tudo").tag(250_000)
                            }
                            .pickerStyle(.menu)
                            Button("Analisar novas") { Task { await model.scan(limit: scanSelection) } }
                                .buttonStyle(.borderedProminent)
                                .disabled(model.busy)
                        }
                        Button("Criar / atualizar álbuns (\(store.readyToApply.count))") {
                            Task { await model.applySuggested() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.busy || store.readyToApply.isEmpty)
                        if model.busy { ProgressView(model.progress) }
                        stats
                        if store.ordered.isEmpty {
                            ContentUnavailableView("Nenhuma imagem analisada", systemImage: "photo.badge.plus",
                                description: Text("Toque em Analisar novas para começar."))
                        } else {
                            Text("Imagens identificadas").font(.title3.bold())
                            ForEach(store.ordered.prefix(200)) { record in
                                PhotoRecordRow(record: record, model: model)
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(OrgaColors.background)
            .navigationTitle("Foteka")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) { FotekaLayerMark() ; Text("Foteka").font(.title.bold()) }\n                    Text("Suas coleções")
                .font(.title2.bold())
            Text("Fotos organizadas por assunto, no seu iPhone.")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            statCard("Analisadas", "\(store.records.count)", "photo.stack")
            statCard("Revisar", "\(store.reviewItems.count)", "questionmark.circle")
            statCard("Em álbuns", "\(store.ordered.filter { $0.appliedCategory != nil }.count)", "checkmark.seal")
        }
    }
    private func statCard(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(OrgaColors.primary)
            Text(value).font(.title2.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(OrgaColors.mint, in: RoundedRectangle(cornerRadius: 14))
    }
    private var accessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Permissão necessária", systemImage: "lock.shield")
                .font(.headline)
            Text("Para classificar imagens e criar álbuns, permita acesso às fotos. Acesso limitado organizará apenas as fotos selecionadas.")
                .font(.subheadline)
            Button("Autorizar acesso às Fotos") { Task { await model.authorize() } }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrgaColors.mint, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PhotoRecordRow: View {
    let record: PhotoRecord
    @ObservedObject var model: LibraryViewModel

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnail(id: record.id)
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: record.selectedCategory.symbol)
                    Text(record.selectedCategory.title).font(.subheadline.bold())
                }
                Text("Confiança \(Int(record.classification.confidence * 100))% · \(record.appliedCategory != nil ? "No álbum" : "Pendente")")
                    .foregroundStyle(.secondary).font(.caption)
                if !record.classification.evidence.isEmpty {
                    Text(record.classification.evidence.joined(separator: ", "))
                        .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Spacer(minLength: 1)
            Menu {
                ForEach(PhotoCategory.allCases) { category in
                    Button { model.correct(id: record.id, to: category) } label: {
                        Label(category.title, systemImage: category.symbol)
                    }
                }
            } label: {
                Image(systemName: "square.and.pencil").font(.title3).padding(8)
                    .accessibilityLabel("Corrigir categoria")
            }
        }
        .padding(11)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
    }
}

struct PhotoThumbnail: View {
    let id: String
    @State private var photo: UIImage?
    var body: some View {
        ZStack {
            Color.secondary.opacity(0.15)
            if let photo { Image(uiImage: photo).resizable().scaledToFill() }
            else { Image(systemName: "photo").foregroundStyle(.secondary) }
        }
        .clipped()
        .task(id: id) {
            guard let asset = PhotoLibraryService.shared.asset(id: id) else { return }
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            PHImageManager.default().requestImage(for: asset,
                                                   targetSize: CGSize(width: 160, height: 160),
                                                   contentMode: .aspectFill, options: options) { image, _ in
                DispatchQueue.main.async { photo = image }
            }
        }
    }
}

struct ReviewTab: View {
    @ObservedObject var model: LibraryViewModel
    @ObservedObject var store: CatalogStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Revise sugestões com baixa confiança. Sua correção fortalece regras locais para as próximas imagens.")
                        .foregroundStyle(.secondary)
                    if store.reviewItems.isEmpty {
                        ContentUnavailableView("Nada para revisar", systemImage: "checkmark.circle", description: Text("As imagens incertas aparecerão aqui."))
                    }
                    ForEach(store.reviewItems) { record in
                        PhotoRecordRow(record: record, model: model)
                        Button("Confirmar \(record.selectedCategory.title)") {
                            model.correct(id: record.id, to: record.selectedCategory)
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    Button("Aplicar categorias confirmadas") { Task { await model.applySuggested() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.busy || store.readyToApply.isEmpty)
                }
                .padding(18)
            }
            .navigationTitle("Revisão")
        }
    }
}

struct RulesTab: View {
    @ObservedObject var store: CatalogStore
    @State private var word = ""
    @State private var category: PhotoCategory = .projetos
    @State private var confirmReset = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Nova regra personalizada") {
                    TextField("Palavra-chave (ex.: portus)", text: $word)
                        .textInputAutocapitalization(.never)
                    Picker("Destino", selection: $category) {
                        ForEach(PhotoCategory.allCases) { item in Text(item.title).tag(item) }
                    }
                    Button("Adicionar regra") {
                        store.addRule(word: word, category: category)
                        word = ""
                    }
                    .disabled(RuleEngine.tokens(from: word).isEmpty)
                }
                Section("Aprendizado local") {
                    Text("\(store.learned.count) palavras-chave aprendidas")
                    ForEach(store.learned.keys.sorted().prefix(60), id: \.self) { key in
                        HStack {
                            Text(key)
                            Spacer()
                            Text(store.learned[key]?.max(by: { $0.value < $1.value })?.key ?? "")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("Limpar regras aprendidas", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Regras")
            .confirmationDialog("Excluir apenas as regras aprendidas?", isPresented: $confirmReset) {
                Button("Limpar regras", role: .destructive) { store.resetLearnedRules() }
            }
        }
    }
}

struct SettingsTab: View {
    @ObservedObject var model: LibraryViewModel
    @ObservedObject var store: CatalogStore
    var body: some View {
        NavigationStack {
            Form {
                Section("Automação") {
                    Toggle("Analisar fotos novas ao abrir o app", isOn: $store.autoScan)
                    Toggle("Criar álbuns automaticamente para sugestões confiáveis", isOn: $store.autoApply)
                    Text("Autoaplicar só ocorre durante uma análise iniciada no app e exige confiança de pelo menos 80%. A primeira organização pode ser conferida antes de aplicar.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Importar arquivos recebidos via Compartilhar") { Task { await model.importInbox(); await model.scan(limit: 100) } }
                        .disabled(model.busy)
                }
                Section("Importação") {
                    Text("No Safari ou Arquivos: Compartilhar → OrgaIA. Em Atalhos: ação 'Enviar imagem para OrgaIA' com a entrada Arquivo ou Imagem.")
                    Text("Arquivos compartilhados ficam numa fila local até a próxima abertura do aplicativo.")
                }
                Section("Privacidade") {
                    Text("Nenhuma imagem é enviada a um servidor. A IA usa Vision no próprio aparelho. As fotos originais são mantidas; somente álbuns OrgaIA são editados.")
                    Text("Fotos do iCloud não baixadas podem precisar de conexão ou download prévio para análise.")
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}
