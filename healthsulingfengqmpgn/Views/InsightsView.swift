import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore
    @State private var search = ""

    private var searchResults: [ArticleDefinition] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return ArticleCatalog.allArticles.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.categoryKey.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    PremiumBanner(
                        title: "Unlock All Features",
                        subtitle: "Try Premium for Free",
                        context: .insights
                    )
                    searchField

                    if !search.isEmpty {
                        searchList
                    } else {
                        popularSection
                        ForEach(ArticleCatalog.categories) { category in
                            categorySection(category)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Learn your heart")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text("\(ArticleCatalog.allArticles.count) articles across \(ArticleCatalog.categories.count) topics, written for everyday understanding.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.inkSecondary)
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.inkSecondary)
            TextField("Search articles", text: $search)
                .font(.system(size: 14))
                .foregroundColor(AppColors.ink)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.inkSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.separator.opacity(0.7), lineWidth: 1)
        )
    }

    private var searchList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(searchResults.count) results")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
            if searchResults.isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: "Nothing Found", message: "Try another search term.")
                    .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, article in
                        NavigationLink {
                            ArticleDetailView(article: article)
                        } label: {
                            articleRow(article)
                        }
                        .buttonStyle(.plain)
                        if index < searchResults.count - 1 { DividerLine() }
                    }
                }
                .padding(.horizontal, 14)
                .cardStyle(padding: 0)
            }
        }
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Popular Now")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ArticleCatalog.popular) { article in
                        NavigationLink {
                            ArticleDetailView(article: article)
                        } label: {
                            popularCard(article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func popularCard(_ article: ArticleDefinition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [article.color.opacity(0.9), article.color.opacity(0.55)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(width: 210, height: 105)
                .overlay(Color.black.opacity(0.1))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: article.category?.icon ?? "book.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(.white.opacity(0.25))
                        .padding(10)
                }
                Text(article.category?.title ?? "")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.88))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.16), in: Capsule())
                    .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(article.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Text("\(article.pageCount) pages")
                .font(.system(size: 10))
                .foregroundColor(AppColors.inkSecondary)
        }
        .frame(width: 210, alignment: .leading)
    }

    private func categorySection(_ category: ArticleCategoryDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(category.color)
                Text(category.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Spacer()
                Text("\(category.articles.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Text(category.subtitle)
                .font(.system(size: 12))
                .foregroundColor(AppColors.inkSecondary)

            if category.horizontal {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(category.articles) { article in
                            NavigationLink {
                                ArticleDetailView(article: article)
                            } label: {
                                horizontalCard(article, category: category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(category.articles.enumerated()), id: \.element.id) { index, article in
                        NavigationLink {
                            ArticleDetailView(article: article)
                        } label: {
                            articleRow(article)
                        }
                        .buttonStyle(.plain)
                        if index < category.articles.count - 1 { DividerLine() }
                    }
                }
                .padding(.horizontal, 14)
                .cardStyle(padding: 0)
            }
        }
    }

    private func horizontalCard(_ article: ArticleDefinition, category: ArticleCategoryDefinition) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(category.color.opacity(0.15))
                .frame(width: 172, height: 84)
                .overlay {
                    Image(systemName: category.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(category.color.opacity(0.8))
                }
            Text(article.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 4) {
                if article.isPopular {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(AppColors.gold)
                }
                Text("\(article.pageCount) pages")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.inkSecondary)
                if app.isArticleRead(article.id) {
                    Text("· Read")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.success)
                }
            }
        }
        .frame(width: 172, alignment: .leading)
        .padding(10)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func articleRow(_ article: ArticleDefinition) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((article.category?.color ?? AppColors.coral).opacity(0.13))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: article.category?.icon ?? "book.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(article.category?.color ?? AppColors.coral)
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(article.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.ink)
                        .lineLimit(1)
                    if article.isPopular {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(AppColors.gold)
                    }
                }
                HStack(spacing: 6) {
                    Text("\(article.pageCount) pages")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.inkSecondary)
                    if app.isArticleRead(article.id) {
                        Text("Read")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.success)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary.opacity(0.5))
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct ArticleDetailView: View {
    let article: ArticleDefinition
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel
    @State private var page = 0

    private var pages: [ArticlePage] { ArticleCatalog.pages(for: article) }
    private var category: ArticleCategoryDefinition? { article.category }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    banner
                    if let current = pages[safe: page] {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(page + 1) of \(pages.count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(category?.color ?? AppColors.coral)
                            Text(current.title)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.ink)
                            Text(current.lead)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(current.body)
                                .font(.system(size: 15))
                                .foregroundColor(AppColors.inkSecondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                        .cardStyle()

                        pageControls
                    }

                    if let category {
                        Link(destination: category.sourceURL) {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                Text("Source")
                                Spacer()
                                Text(category.title)
                                    .foregroundColor(AppColors.inkSecondary)
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(category.color)
                            .padding(14)
                            .cardStyle(padding: 0)
                        }
                    }

                    Text("Educational content only. It does not replace advice from a qualified clinician.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.inkSecondary)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            app.markArticleRead(article.id)
        }
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [(category?.color ?? AppColors.coral).opacity(0.95),
                         (category?.color ?? AppColors.coral).opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 180)
            LinearGradient(colors: [.clear, .black.opacity(0.38)], startPoint: .top, endPoint: .bottom)
                .frame(height: 180)
            Image(systemName: category?.icon ?? "book.fill")
                .font(.system(size: 100, weight: .semibold))
                .foregroundColor(.white.opacity(0.16))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 18)
            VStack(alignment: .leading, spacing: 5) {
                if let category {
                    Text(category.title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.8))
                }
                Text(article.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if article.isPopular {
                    Label("Popular", systemImage: "star.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var pageControls: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation { page = max(0, page - 1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(width: 64)
            .disabled(page == 0)
            .opacity(page == 0 ? 0.4 : 1)

            HStack(spacing: 5) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(index == page ? (category?.color ?? AppColors.coral) : AppColors.separator)
                        .frame(width: index == page ? 9 : 6, height: index == page ? 9 : 6)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    dismiss()
                }
            } label: {
                Text(page == pages.count - 1 ? "Done" : "Next")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(PrimaryButtonStyle(tint: category?.color ?? AppColors.coral))
            .frame(width: 92)
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
