import SwiftUI

struct BulletinBoardView: View {

    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var viewModel: BulletinViewModel
    @State private var showCompose = false

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.pinnedBulletins.isEmpty {
                    Section("Pinned") {
                        ForEach(viewModel.pinnedBulletins) { bulletin in
                            BulletinCard(
                                bulletin: bulletin,
                                authorName: auth.displayName(for: bulletin.authorId),
                                isOwner: bulletin.authorId == auth.currentUser?.id,
                                onPin: { Task { await viewModel.togglePin(bulletin) } },
                                onDelete: { Task { await viewModel.delete(bulletin) } }
                            )
                        }
                    }
                }

                Section(viewModel.pinnedBulletins.isEmpty ? "Posts" : "Recent") {
                    if viewModel.unpinnedBulletins.isEmpty && viewModel.pinnedBulletins.isEmpty {
                        ContentUnavailableView(
                            "Nothing posted yet",
                            systemImage: "pin.circle",
                            description: Text("Be the first to post on the board.")
                        )
                    } else {
                        ForEach(viewModel.unpinnedBulletins) { bulletin in
                            BulletinCard(
                                bulletin: bulletin,
                                authorName: auth.displayName(for: bulletin.authorId),
                                isOwner: bulletin.authorId == auth.currentUser?.id,
                                onPin: { Task { await viewModel.togglePin(bulletin) } },
                                onDelete: { Task { await viewModel.delete(bulletin) } }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Bulletin Board")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCompose = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showCompose) {
                ComposeBulletinView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Bulletin Card

struct BulletinCard: View {
    let bulletin: Bulletin
    let authorName: String
    let isOwner: Bool
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if bulletin.isUrgent {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                        if bulletin.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.accentColor)
                                .font(.caption)
                        }
                        Text(bulletin.title)
                            .font(.headline)
                    }
                    Text("\(authorName) · \(bulletin.createdAt.timeAgoDisplay)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(bulletin.content)
                .font(.subheadline)
                .lineLimit(4)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isOwner {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            Button { onPin() } label: {
                Label(bulletin.isPinned ? "Unpin" : "Pin", systemImage: bulletin.isPinned ? "pin.slash" : "pin")
            }
            .tint(.accentColor)
        }
    }
}
