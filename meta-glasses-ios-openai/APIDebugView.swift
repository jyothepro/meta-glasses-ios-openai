//
//  APIDebugView.swift
//  meta-glasses-ios-openai
//
//  Admin view to inspect all AI API calls, responses, and images
//

import SwiftUI

// MARK: - API Debug View (Main List)

struct APIDebugView: View {
    @ObservedObject private var debugLogger = APIDebugLogger.shared
    @State private var selectedService: APIService? = nil
    @State private var showErrorsOnly: Bool = false
    @State private var selectedEntry: APILogEntry? = nil

    private var filteredEntries: [APILogEntry] {
        var result = debugLogger.entries

        if let service = selectedService {
            result = result.filter { $0.service == service }
        }

        if showErrorsOnly {
            result = result.filter { !$0.isSuccess }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            FilterBar(
                selectedService: $selectedService,
                showErrorsOnly: $showErrorsOnly,
                totalCount: debugLogger.entries.count,
                errorCount: debugLogger.errorEntries().count
            )

            if filteredEntries.isEmpty {
                EmptyStateView(isFiltered: selectedService != nil || showErrorsOnly)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        APILogEntryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("API Debug Log")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Logging Enabled", isOn: $debugLogger.isEnabled)

                    Divider()

                    Button(role: .destructive) {
                        debugLogger.clear()
                    } label: {
                        Label("Clear Logs", systemImage: "trash")
                    }

                    Button {
                        shareExportedLogs()
                    } label: {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                APILogDetailView(entry: entry)
            }
        }
    }

    private func shareExportedLogs() {
        guard let json = debugLogger.exportAsJSON() else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("api_debug_log_\(Date().timeIntervalSince1970).json")

        do {
            try json.write(to: tempURL, atomically: true, encoding: .utf8)

            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Failed to export logs: \(error)")
        }
    }
}

// MARK: - Filter Bar

private struct FilterBar: View {
    @Binding var selectedService: APIService?
    @Binding var showErrorsOnly: Bool
    let totalCount: Int
    let errorCount: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All filter
                FilterChip(
                    title: "All",
                    count: totalCount,
                    isSelected: selectedService == nil && !showErrorsOnly,
                    color: .secondary
                ) {
                    selectedService = nil
                    showErrorsOnly = false
                }

                // Errors filter
                FilterChip(
                    title: "Errors",
                    count: errorCount,
                    isSelected: showErrorsOnly,
                    color: .red
                ) {
                    showErrorsOnly.toggle()
                    if showErrorsOnly {
                        selectedService = nil
                    }
                }

                Divider()
                    .frame(height: 20)

                // Service filters
                ForEach(APIService.allCases, id: \.self) { service in
                    FilterChip(
                        title: service.rawValue,
                        icon: service.icon,
                        isSelected: selectedService == service,
                        color: serviceColor(service)
                    ) {
                        if selectedService == service {
                            selectedService = nil
                        } else {
                            selectedService = service
                            showErrorsOnly = false
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
    }

    private func serviceColor(_ service: APIService) -> Color {
        switch service {
        case .openAIRealtime: return .purple
        case .openAIChat: return .green
        case .openAIVision: return .blue
        case .perplexity: return .orange
        case .geminiLive: return .red
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var count: Int? = nil
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption.bold())
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.3) : color.opacity(0.3))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color : Color(.tertiarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    let isFiltered: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle" : "network.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(isFiltered ? "No matching entries" : "No API calls yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(isFiltered ? "Try adjusting your filters" : "API calls will appear here as they happen")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Log Entry Row

private struct APILogEntryRow: View {
    let entry: APILogEntry

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(entry.isSuccess ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            // Service icon
            Image(systemName: entry.service.icon)
                .font(.body)
                .foregroundColor(serviceColor)
                .frame(width: 24)

            // Main content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.endpoint)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    Spacer()

                    Text(entry.formattedTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(entry.requestSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Metadata row
                HStack(spacing: 8) {
                    if let duration = entry.formattedDuration {
                        Label(duration, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let code = entry.statusCode {
                        Text("\(code)")
                            .font(.caption2.bold())
                            .foregroundColor(entry.isSuccess ? .green : .red)
                    }

                    if !entry.requestImages.isEmpty {
                        Label("\(entry.requestImages.count)", systemImage: "photo")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }

                    if entry.isWebSocket {
                        Label("WS", systemImage: "bolt.horizontal")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var serviceColor: Color {
        switch entry.service {
        case .openAIRealtime: return .purple
        case .openAIChat: return .green
        case .openAIVision: return .blue
        case .perplexity: return .orange
        case .geminiLive: return .red
        }
    }
}

// MARK: - Log Detail View

private struct APILogDetailView: View {
    let entry: APILogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HeaderSection(entry: entry)

                Divider()

                // Request section
                if !entry.requestSummary.isEmpty || !entry.requestImages.isEmpty {
                    RequestSection(entry: entry)
                    Divider()
                }

                // Response section
                if entry.responseSummary != nil || !entry.responseImages.isEmpty || entry.error != nil {
                    ResponseSection(entry: entry)
                }
            }
            .padding()
        }
        .navigationTitle("API Call Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Header Section

private struct HeaderSection: View {
    let entry: APILogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Service badge
            HStack {
                Image(systemName: entry.service.icon)
                Text(entry.service.rawValue)
                    .font(.headline)

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.isSuccess ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(entry.isSuccess ? "Success" : "Failed")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((entry.isSuccess ? Color.green : Color.red).opacity(0.15))
                .cornerRadius(8)
            }

            // Endpoint
            HStack {
                Text(entry.method)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(4)

                Text(entry.endpoint)
                    .font(.subheadline.monospaced())
            }

            // Metadata
            HStack(spacing: 16) {
                Label(entry.formattedTimestamp, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let duration = entry.formattedDuration {
                    Label(duration, systemImage: "stopwatch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let code = entry.statusCode {
                    Label("\(code)", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(entry.isSuccess ? .green : .red)
                }

                if entry.isWebSocket {
                    Label("WebSocket", systemImage: "bolt.horizontal")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
        }
    }
}

// MARK: - Request Section

private struct RequestSection: View {
    let entry: APILogEntry
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Label("Request", systemImage: "arrow.up.circle")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Images
                if !entry.requestImages.isEmpty {
                    Text("Images (\(entry.requestImages.count))")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(entry.requestImages.enumerated()), id: \.offset) { index, imageData in
                                ImagePreview(imageData: imageData, label: "Request \(index + 1)")
                            }
                        }
                    }
                }

                // Request body
                if !entry.requestSummary.isEmpty {
                    Text("Body")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Text(entry.requestSummary)
                        .font(.caption.monospaced())
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Response Section

private struct ResponseSection: View {
    let entry: APILogEntry
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Label("Response", systemImage: "arrow.down.circle")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Error
                if let error = entry.error {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Error")
                            .font(.caption.bold())
                            .foregroundColor(.red)

                        Text(error)
                            .font(.caption.monospaced())
                            .foregroundColor(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                // Images
                if !entry.responseImages.isEmpty {
                    Text("Images (\(entry.responseImages.count))")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(entry.responseImages.enumerated()), id: \.offset) { index, imageData in
                                ImagePreview(imageData: imageData, label: "Response \(index + 1)")
                            }
                        }
                    }
                }

                // Response body
                if let response = entry.responseSummary {
                    Text("Body")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    Text(response)
                        .font(.caption.monospaced())
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Image Preview

private struct ImagePreview: View {
    let imageData: Data
    let label: String
    @State private var showFullScreen: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 90)
                    .clipped()
                    .cornerRadius(8)
                    .onTapGesture {
                        showFullScreen = true
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 120, height: 90)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(formatBytes(imageData.count))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenImageView(imageData: imageData)
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}

// MARK: - Full Screen Image View

private struct FullScreenImageView: View {
    let imageData: Data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        APIDebugView()
    }
}
