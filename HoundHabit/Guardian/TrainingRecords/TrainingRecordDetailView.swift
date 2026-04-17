import SwiftUI

struct TrainingRecordDetailView: View {
    let record: TrainingRecord
    let petName: String
    let viewModel: TrainingRecordViewModel

    // Read-only mode: hides Edit / Delete (used by Trainer)
    var isReadOnly: Bool = false

    // Comment thread — pass externally (Trainer) or self-load (Guardian)
    var comments: [Comment] = []
    var onAddComment: ((String) async -> Void)? = nil
    var onDeleteComment: ((Comment) async -> Void)? = nil
    // When true, the view self-loads comments (Guardian read-only mode)
    var selfLoadComments: Bool = false

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var newCommentBody = ""
    @State private var isSendingComment = false
    @State private var selfLoadedComments: [Comment] = []
    @State private var behaviorName: String? = nil
    @Environment(\.dismiss) private var dismiss

    private let commentService = CommentService()
    private let planService = TrainingPlanService()

    private var current: TrainingRecord? {
        viewModel.records.first { $0.id == record.id }
    }

    private var displayRecord: TrainingRecord? {
        isReadOnly ? record : current
    }

    private var effectiveComments: [Comment] {
        selfLoadComments ? selfLoadedComments : comments
    }

    private var showComments: Bool {
        selfLoadComments || onAddComment != nil || !comments.isEmpty
    }

    var body: some View {
        Group {
            if let r = displayRecord {
                recordContent(r)
                    .onChange(of: current == nil) { _, isGone in
                        if isGone && !isReadOnly { dismiss() }
                    }
            }
        }
    }

    @ViewBuilder
    private func recordContent(_ r: TrainingRecord) -> some View {
        List {
            recordSections(r)
            if showComments { commentSection }
            if !isReadOnly { deleteSection }
        }
        .navigationTitle(r.recordedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isReadOnly {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEditSheet = true }
                }
            }
        }
        .task(id: r.id) {
            async let fetchedComments: [Comment] = {
                guard selfLoadComments else { return [] }
                return (try? await commentService.fetchComments(recordId: r.id)) ?? []
            }()
            async let fetchedBehavior: String? = {
                guard let itemId = r.planItemId else { return nil }
                return try? await planService.fetchBehaviorName(for: itemId)
            }()
            // Await both concurrently, then assign on the main actor (.task inherits main actor isolation)
            selfLoadedComments = await fetchedComments
            behaviorName = await fetchedBehavior
        }
        .sheet(isPresented: $showEditSheet) {
            TrainingRecordFormView(existingRecord: r, petName: petName) { updated in
                Task { await viewModel.updateRecord(updated) }
            }
        }
        .confirmationDialog(
            "Delete this session?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteRecord(r)
                    dismiss()
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    @ViewBuilder
    private func recordSections(_ r: TrainingRecord) -> some View {
        Section("Pet") {
            Text(petName)
        }

        Section("Status") {
            HStack(spacing: 12) {
                StatusBadgeView(status: r.status, size: 24)
                Text(r.status.label)
                    .font(.headline)
            }
            .padding(.vertical, 4)
        }

        Section("Date") {
            Text(r.recordedAt.formatted(date: .long, time: .omitted))
        }

        Section("Three D's") {
            if let behaviorName {
                LabeledContent("Behavior", value: behaviorName)
            }
            LabeledContent("Distance",    value: r.distance.label)
            LabeledContent("Distraction", value: r.distraction.label)
            LabeledContent("Duration",    value: r.duration.label)
        }

        if let notes = r.notes, !notes.isEmpty {
            Section("Notes") {
                Text(notes)
            }
        }

        // Sharing is controlled at the plan level for plan-linked sessions.
        // Only show the toggle for standalone sessions.
        if r.planItemId == nil {
            Section {
                if isReadOnly {
                    LabeledContent("Shared with Trainer", value: r.isShared ? "Yes" : "No")
                } else {
                    Toggle("Share with Trainer", isOn: Binding(
                        get: { r.isShared },
                        set: { _ in Task { await viewModel.toggleSharing(r) } }
                    ))
                }
            }
        }
    }

    @ViewBuilder
    private var commentSection: some View {
        Section("Trainer Comments") {
            if effectiveComments.isEmpty {
                Text("No comments yet.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(effectiveComments) { comment in
                    CommentRow(
                        comment: comment,
                        currentUserId: supabase.auth.currentUser?.id,
                        onDelete: deleteHandler(for: comment)
                    )
                }
            }
            if onAddComment != nil {
                CommentInputRow(
                    text: $newCommentBody,
                    isSending: isSendingComment,
                    onSend: sendComment
                )
            }
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Text("Delete Session")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func sendComment() {
        let trimmed = newCommentBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let handler = onAddComment else { return }
        isSendingComment = true
        newCommentBody = ""
        Task {
            await handler(trimmed)
            isSendingComment = false
        }
    }

    private func deleteHandler(for comment: Comment) -> ((Comment) -> Void)? {
        guard let handler = onDeleteComment else { return nil }
        return { c in Task { await handler(c) } }
    }
}

// MARK: - Comment Input Row

private struct CommentInputRow: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Add a comment…", text: $text, axis: .vertical)
                .lineLimit(1...4)
            Button(action: onSend) {
                sendButtonLabel
            }
            .disabled(trimmed.isEmpty || isSending)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var sendButtonLabel: some View {
        if isSending {
            ProgressView()
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(trimmed.isEmpty ? Color.secondary : Color.accentColor)
        }
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: Comment
    let currentUserId: UUID?
    let onDelete: ((Comment) -> Void)?

    private var isOwn: Bool { comment.authorId == currentUserId }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(isOwn ? "You" : "Trainer")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isOwn ? Color.accentColor : Color.secondary)
                Spacer()
                Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(comment.body)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isOwn, let handler = onDelete {
                Button(role: .destructive) {
                    handler(comment)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PreviewContainer()
}

private struct PreviewContainer: View {
    private let vm = TrainingRecordViewModel()
    private let record = TrainingRecord(
        id: UUID(), petId: UUID(), guardianId: UUID(),
        recordedAt: Date(), status: .green, distance: .sixFeet,
        distraction: .none, duration: .fiveSeconds,
        notes: "Great focus today!", isShared: true,
        score: 5, planItemId: nil,
        createdAt: Date(), updatedAt: Date()
    )
    var body: some View {
        let _ = { vm.records = [record] }()
        NavigationStack {
            TrainingRecordDetailView(record: record, petName: "Ozzie", viewModel: vm)
        }
    }
}
