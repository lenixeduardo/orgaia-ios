import SwiftUI

// Visual Collections: primary presentation style approved for OrgaIA.
// Real PhotoKit thumbnails are used only when the user grants photo access.
enum OrgaColors {
    static let background = Color(red: 248/255, green: 247/255, blue: 243/255)
    static let surface = Color(red: 255/255, green: 254/255, blue: 252/255)
    static let primary = Color(red: 11/255, green: 113/255, blue: 119/255)
    static let primaryDark = Color(red: 6/255, green: 79/255, blue: 85/255)
    static let mint = Color(red: 233/255, green: 243/255, blue: 240/255)
    static let ink = Color(red: 24/255, green: 51/255, blue: 59/255)
    static let secondary = Color(red: 100/255, green: 118/255, blue: 120/255)
}

struct CollectionHero: View {
    let photoID: String?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [OrgaColors.primaryDark, OrgaColors.primary],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let photoID {
                PhotoThumbnail(id: photoID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 176)
                    .clipped()
            }
            LinearGradient(colors: [.clear, Color.black.opacity(0.68)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                Text("Organize o que")
                Text("importa para você.")
            }
            .font(.title3.bold())
            .foregroundStyle(.white)
            .padding(18)
        }
        .frame(height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct CollectionGrid: View {
    @ObservedObject var model: LibraryViewModel
    @ObservedObject var store: CatalogStore
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(PhotoCategory.allCases) { category in
                NavigationLink {
                    CollectionDetailView(category: category, model: model, store: store)
                } label: {
                    CollectionTile(
                        category: category,
                        previewID: store.ordered.first(where: { $0.selectedCategory == category })?.id,
                        count: store.ordered.filter { $0.selectedCategory == category }.count
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CollectionTile: View {
    let category: PhotoCategory
    let previewID: String?
    let count: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            OrgaColors.mint
            if let previewID {
                PhotoThumbnail(id: previewID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 158)
                    .clipped()
                LinearGradient(colors: [.clear, Color.black.opacity(0.72)],
                               startPoint: .center, endPoint: .bottom)
            } else {
                Image(systemName: category.symbol)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(OrgaColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(count == 0 ? "Aguardando imagens" : "\(count) imagens")
                    .font(.caption2)
                    .opacity(0.9)
            }
            .foregroundStyle(previewID == nil ? OrgaColors.ink : .white)
            .padding(12)
        }
        .frame(height: 158)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.title), \(count) imagens analisadas")
        .accessibilityAddTraits(.isButton)
    }
}

struct CollectionDetailView: View {
    let category: PhotoCategory
    @ObservedObject var model: LibraryViewModel
    @ObservedObject var store: CatalogStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let filtered = store.ordered.filter { $0.selectedCategory == category }
                if filtered.isEmpty {
                    ContentUnavailableView("Nenhuma imagem nesta categoria",
                        systemImage: category.symbol,
                        description: Text("As próximas imagens classificadas aparecerão aqui."))
                } else {
                    ForEach(filtered) { record in
                        PhotoRecordRow(record: record, model: model)
                    }
                }
            }
            .padding(18)
        }
        .background(OrgaColors.background)
        .navigationTitle(category.title)
    }
}
