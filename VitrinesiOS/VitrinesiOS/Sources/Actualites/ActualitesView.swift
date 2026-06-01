// ActualitesView.swift
// Vitrines d'Alençon — iOS
// Onglet Actualités : blog.post (website_blog), réplique de /blog.

import SwiftUI
import Combine

// MARK: - Modèle

struct BlogPost: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
    let subtitle: String?
    let teaser: String?
    let postDate: String?
    let authorName: String?
    let blogName: String?
    let coverProperties: String?

    enum CodingKeys: String, CodingKey {
        case id, name, subtitle, teaser
        case postDate = "post_date"
        case authorId = "author_id"
        case blogId = "blog_id"
        case coverProperties = "cover_properties"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        subtitle = try? c.decode(String.self, forKey: .subtitle)
        teaser = try? c.decode(String.self, forKey: .teaser)
        postDate = try? c.decode(String.self, forKey: .postDate)
        coverProperties = try? c.decode(String.self, forKey: .coverProperties)
        authorName = Self.m2oName(c, .authorId)
        blogName = Self.m2oName(c, .blogId)
    }

    private static func m2oName(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        guard var u = try? c.nestedUnkeyedContainer(forKey: key) else { return nil }
        _ = try? u.decode(Int.self)
        return try? u.decode(String.self)
    }

    var coverImageURL: URL? {
        guard let cp = coverProperties,
              let range = cp.range(of: "url\\(([^)]+)\\)", options: .regularExpression) else { return nil }
        let s = String(cp[range])
            .replacingOccurrences(of: "url(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "\\", with: "")   // quotes échappées \" dans cover_properties
            .trimmingCharacters(in: CharacterSet(charactersIn: "'\" "))
        guard !s.isEmpty, s != "none" else { return nil }
        let full = s.hasPrefix("http") ? s : OdooConfig.baseURL + s
        // L'URL de cover_properties est DÉJÀ percent-encodée → ne pas ré-encoder (sinon %20 → %2520).
        return URL(string: full)
    }

    var excerpt: String? {
        (teaser ?? subtitle)?.htmlStripped.nilIfBlank
    }

    var dateLabel: String {
        guard let raw = postDate, let d = CouponDetailView.parseOdooDate(raw) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: d)
    }

    var authorInitial: String { String(authorName?.first ?? "A").uppercased() }

    static func == (lhs: BlogPost, rhs: BlogPost) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private extension String {
    var nilIfBlank: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}

private struct BlogContentRow: Decodable { let content: String? }

// MARK: - ViewModel

@MainActor
final class ActualitesViewModel: ObservableObject {
    @Published var posts: [BlogPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client = OdooClient.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            posts = try await client.call(
                model: "blog.post", method: "search_read", args: [],
                kwargs: ["domain": [["website_published", "=", true]],
                         "fields": ["name", "subtitle", "teaser", "post_date",
                                    "author_id", "blog_id", "cover_properties"],
                         "order": "post_date desc", "limit": 50]
            )
        } catch {
            errorMessage = (error as? OdooError)?.errorDescription ?? error.localizedDescription
        }
    }

    func content(for id: Int) async -> String? {
        let rows: [BlogContentRow]? = try? await client.call(
            model: "blog.post", method: "search_read", args: [],
            kwargs: ["domain": [["id", "=", id]], "fields": ["content"], "limit": 1]
        )
        return rows?.first?.content?.htmlStripped
    }

    /// Un article par id (pour l'ouvrir depuis une notification).
    func fetchPost(id: Int) async -> BlogPost? {
        let rows: [BlogPost]? = try? await client.call(
            model: "blog.post", method: "search_read", args: [],
            kwargs: ["domain": [["id", "=", id]],
                     "fields": ["name", "subtitle", "teaser", "post_date",
                                "author_id", "blog_id", "cover_properties"], "limit": 1]
        )
        return rows?.first
    }
}

// MARK: - Liste

struct ActualitesView: View {
    @StateObject private var viewModel = ActualitesViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Nos dernières publications")
                        .font(BrandFont.serif(26, weight: .bold))
                        .foregroundStyle(Color.brandNavy)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)

                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                    } else if let error = viewModel.errorMessage, viewModel.posts.isEmpty {
                        ContentUnavailableView {
                            Label("Erreur", systemImage: "wifi.exclamationmark")
                        } description: { Text(error) } actions: {
                            Button("Réessayer") { Task { await viewModel.load() } }
                                .buttonStyle(.borderedProminent).tint(Color.brandNavy)
                        }
                    } else if viewModel.posts.isEmpty {
                        ContentUnavailableView("Aucune publication", systemImage: "newspaper")
                            .padding(.top, 60)
                    } else {
                        ForEach(viewModel.posts) { post in
                            NavigationLink(value: post) { BlogCard(post: post) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: BlogPost.self) { post in
                BlogPostDetailView(post: post, viewModel: viewModel)
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }
}

// MARK: - Carte article

private struct BlogCard: View {
    let post: BlogPost

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            cover
            Text(post.name)
                .font(BrandFont.serif(20, weight: .bold))
                .foregroundStyle(Color.brandNavy)
                .fixedSize(horizontal: false, vertical: true)
            if let excerpt = post.excerpt {
                Text(excerpt)
                    .font(BrandFont.sans(14))
                    .foregroundStyle(Color.brandTextMuted)
                    .lineLimit(3)
            }
            HStack {
                Text(post.dateLabel)
                    .font(BrandFont.sans(13, weight: .semibold))
                    .foregroundStyle(Color.brandNavy)
                Spacer()
                if let blog = post.blogName {
                    Label(blog, systemImage: "folder")
                        .font(BrandFont.sans(12))
                        .foregroundStyle(Color.brandNavy)
                        .lineLimit(1)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var cover: some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                BlogCoverImage(url: post.coverImageURL)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 8) {
                    Text(post.authorInitial)
                        .font(BrandFont.sans(12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.brandNavy, in: .circle)
                    if let author = post.authorName {
                        Text(author)
                            .font(BrandFont.sans(13, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                .padding(10)
                .background(
                    LinearGradient(colors: [.black.opacity(0.5), .clear],
                                   startPoint: .bottom, endPoint: .top)
                )
            }
    }
}

private struct BlogCoverImage: View {
    let url: URL?
    var body: some View {
        RemoteImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            default:
                ZStack {
                    Color.brandSurface2
                    Image(systemName: "newspaper").font(.largeTitle).foregroundStyle(Color.brandNavy.opacity(0.4))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Fiche article

struct BlogPostDetailView: View {
    let post: BlogPost
    @ObservedObject var viewModel: ActualitesViewModel
    @State private var content: String?
    @State private var loadingContent = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let blog = post.blogName {
                    Label(blog, systemImage: "folder")
                        .font(BrandFont.sans(13, weight: .semibold))
                        .foregroundStyle(Color.brandNavy)
                }
                Text(post.name)
                    .font(BrandFont.serif(28, weight: .bold))
                    .foregroundStyle(Color.brandNavy)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = post.subtitle?.htmlStripped, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(BrandFont.sans(17))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                    Text("\(post.dateLabel) par \(post.authorName ?? "")")
                }
                .font(BrandFont.sans(13))
                .foregroundStyle(Color.brandTextMuted)

                // Cover en entier, adaptée à la largeur (ratio naturel) — pas de recadrage.
                if post.coverImageURL != nil {
                    RemoteImage(url: post.coverImageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        case .empty:
                            ZStack { Color.brandSurface2; ProgressView() }
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        case .failure:
                            EmptyView()
                        }
                    }
                }

                if loadingContent {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                } else if let content, !content.isEmpty {
                    Text(content)
                        .font(BrandFont.sans(16))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            content = await viewModel.content(for: post.id)
            loadingContent = false
        }
    }
}
