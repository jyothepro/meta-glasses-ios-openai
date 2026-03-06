//
//  CaptureDetailView.swift
//  meta-glasses-ios-openai
//
//  Detail view for reviewing past conversation captures
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "CaptureDetail")

// MARK: - Detail Tab

private enum CaptureDetailTab: String, CaseIterable {
    case summary = "Summary"
    case transcript = "Transcript"
}

// MARK: - Capture Detail View

struct CaptureDetailView: View {
    let captureId: UUID

    @ObservedObject private var store = CaptureStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: CaptureDetailTab = .summary
    @State private var showDeleteConfirmation = false
    @State private var editableTitle: String = ""
    @State private var isEditingTitle = false

    private var session: CaptureSession? {
        store.session(for: captureId)
    }

    private var transcript: Transcript? {
        store.loadTranscript(for: captureId)
    }

    private var summary: CaptureSummary? {
        store.loadSummary(for: captureId)
    }

    var body: some View {
        Group {
            if let session {
                VStack(spacing: 0) {
                    // Tab picker
                    Picker("View", selection: $selectedTab) {
                        ForEach(CaptureDetailTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Tab content
                    switch selectedTab {
                    case .summary:
                        summaryTab(session: session)
                    case .transcript:
                        transcriptTab
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        if isEditingTitle {
                            TextField("Title", text: $editableTitle, onCommit: {
                                saveTitle()
                            })
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        } else {
                            Button(action: {
                                editableTitle = session.title
                                isEditingTitle = true
                            }) {
                                Text(session.title)
                                    .font(.headline)
                                    .lineLimit(1)
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            if session.transcriptStatus == .failed {
                                Button {
                                    ConversationCaptureManager.shared.setSession(session)
                                    ConversationCaptureManager.shared.retryTranscription()
                                } label: {
                                    Label("Retry Transcription", systemImage: "arrow.clockwise")
                                }
                            }
                            if session.summaryStatus == .failed {
                                Button {
                                    ConversationCaptureManager.shared.setSession(session)
                                    ConversationCaptureManager.shared.retrySummary()
                                } label: {
                                    Label("Retry Summary", systemImage: "arrow.clockwise")
                                }
                            }
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Capture", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .confirmationDialog("Delete this capture?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        store.delete(id: captureId)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The audio, transcript, and summary will be permanently deleted.")
                }
            } else {
                Text("Capture not found")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Summary Tab

    private func summaryTab(session: CaptureSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Metadata
                metadataSection(session: session)

                if let summary {
                    // Key Points
                    if !summary.keyPoints.isEmpty {
                        sectionView(title: "Key Points", icon: "lightbulb") {
                            ForEach(summary.keyPoints, id: \.self) { point in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text(point)
                                }
                                .font(.body)
                            }
                        }
                    }

                    // Decisions
                    if !summary.decisions.isEmpty {
                        sectionView(title: "Decisions", icon: "checkmark.seal") {
                            ForEach(summary.decisions, id: \.self) { decision in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text(decision)
                                }
                                .font(.body)
                            }
                        }
                    }

                    // Action Items
                    if !summary.actionItems.isEmpty {
                        actionItemsSection(items: summary.actionItems)
                    }

                    // Topics
                    if !summary.topics.isEmpty {
                        sectionView(title: "Topics", icon: "tag") {
                            FlowLayout(spacing: 8) {
                                ForEach(summary.topics, id: \.self) { topic in
                                    Text(topic)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                } else if session.summaryStatus == .inProgress {
                    HStack {
                        ProgressView()
                        Text("Generating summary...")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if session.summaryStatus == .failed {
                    VStack(spacing: 8) {
                        Text("Summary generation failed")
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            ConversationCaptureManager.shared.setSession(session)
                            ConversationCaptureManager.shared.retrySummary()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    Text("No summary available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
    }

    // MARK: - Transcript Tab

    private var transcriptTab: some View {
        ScrollView {
            if let transcript, !transcript.segments.isEmpty {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(transcript.segments.enumerated()), id: \.offset) { _, segment in
                        HStack(alignment: .top, spacing: 12) {
                            Text(formatTimestamp(segment.startTime))
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)

                            Text(segment.text)
                                .font(.body)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding()
            } else if let session, session.transcriptStatus == .inProgress {
                VStack {
                    ProgressView()
                    Text("Transcribing...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                Text("No transcript available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
        }
    }

    // MARK: - Sub-components

    private func metadataSection(session: CaptureSession) -> some View {
        HStack(spacing: 16) {
            Label(formatDuration(session.duration), systemImage: "clock")
            Label("\(session.wordCount) words", systemImage: "doc.text")
            Label(session.audioSource.displayName, systemImage: session.audioSource == .glasses ? "eyeglasses" : "mic")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func sectionView<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
    }

    private func actionItemsSection(items: [ActionItem]) -> some View {
        sectionView(title: "Action Items", icon: "checklist") {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.isCompleted ? .green : .secondary)
                        .onTapGesture {
                            toggleActionItem(item)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.description)
                            .font(.body)
                            .strikethrough(item.isCompleted)

                        HStack(spacing: 8) {
                            if let assignee = item.assignee {
                                Text(assignee)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            if let deadline = item.deadline {
                                Text(deadline)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveTitle() {
        let trimmed = editableTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var session else {
            isEditingTitle = false
            return
        }
        session.title = trimmed
        session.updatedAt = Date()
        store.save(session)
        isEditingTitle = false
    }

    private func toggleActionItem(_ item: ActionItem) {
        guard var summary else { return }
        guard let index = summary.actionItems.firstIndex(where: { $0.id == item.id }) else { return }

        var updated = summary.actionItems[index]
        updated.isCompleted.toggle()

        var items = summary.actionItems
        items[index] = updated

        let newSummary = CaptureSummary(
            captureId: summary.captureId,
            keyPoints: summary.keyPoints,
            decisions: summary.decisions,
            actionItems: items,
            sentiment: summary.sentiment,
            topics: summary.topics
        )
        store.saveSummary(newSummary, for: captureId)
    }

    // MARK: - Formatters

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Flow Layout (for topic tags)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
