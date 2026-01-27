//
//  SettingsView.swift
//  meta-glasses-ios-openai
//
//  Created by AI Assistant on 04/01/2026.
//

import SwiftUI
import UIKit
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meta-glasses-ios-openai", category: "SettingsView")

// MARK: - Custom TextView (avoids SwiftUI TextEditor frame bugs)

private struct CustomTextView: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            // Place cursor at the end (delayed to override system's default selection)
            DispatchQueue.main.async {
                let endPosition = textView.endOfDocument
                textView.selectedTextRange = textView.textRange(from: endPosition, to: endPosition)
            }
        }
    }
}

// MARK: - Settings View (Main Menu)

struct SettingsView: View {
    @ObservedObject var glassesManager: GlassesManager
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var isRegeneratingTitles: Bool = false
    @State private var showingRegenerateResult: Bool = false
    @State private var regeneratedCount: Int = 0
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Hardware Section
                Section {
                    NavigationLink {
                        LazyView(GlassesTab(glassesManager: glassesManager))
                    } label: {
                        HStack {
                            Label("Glasses", systemImage: "eyeglasses")
                            Spacer()
                            if glassesManager.glassesErrorCount > 0 {
                                Text("\(glassesManager.glassesErrorCount)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    NavigationLink {
                        StreamingSettingsView()
                    } label: {
                        HStack {
                            Label("Streaming", systemImage: "dot.radiowaves.left.and.right")
                            Spacer()
                            if RTMPStreamManager.shared.state.isLive {
                                Text("LIVE")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            } else if !RTMPStreamManager.shared.settings.isConfigured {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    NavigationLink {
                        PushNotificationTestView()
                    } label: {
                        Label("Push Notifications", systemImage: "bell.badge")
                    }
                } header: {
                    Text("Hardware")
                }
                
                // AI Settings
                Section {
                    NavigationLink {
                        ModelsListView()
                    } label: {
                        HStack {
                            Label("Models", systemImage: "cpu")
                            Spacer()
                            if !settingsManager.isOpenAIConfigured {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    NavigationLink {
                        AdditionalInstructionsView()
                    } label: {
                        Label("Additional Instructions", systemImage: "text.quote")
                    }
                    
                    NavigationLink {
                        MemoriesListView()
                    } label: {
                        Label("Memories", systemImage: "brain")
                    }
                    
                    NavigationLink {
                        AIToolsListView()
                    } label: {
                        HStack {
                            Label("AI Tools", systemImage: "wrench.and.screwdriver")
                            Spacer()
                            Text("\(settingsManager.isPerplexityConfigured ? 3 : 2)/3")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("AI")
                }
                
                // Privacy Section
                Section {
                    NavigationLink {
                        PermissionsView()
                    } label: {
                        HStack {
                            Label("Permissions", systemImage: "hand.raised")
                            Spacer()
                            if permissionsManager.missingRequiredPermissionsCount > 0 {
                                Text("\(permissionsManager.missingRequiredPermissionsCount)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                } header: {
                    Text("Privacy")
                }
                
                // Threads Section
                Section {
                    Button {
                        Task {
                            isRegeneratingTitles = true
                            regeneratedCount = await ThreadsManager.shared.regenerateAllTitles()
                            isRegeneratingTitles = false
                            showingRegenerateResult = true
                        }
                    } label: {
                        HStack {
                            Label("Regenerate All Titles", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if isRegeneratingTitles {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRegeneratingTitles)
                } header: {
                    Text("Threads")
                }
                
                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .alert("Titles Regenerated", isPresented: $showingRegenerateResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Updated \(regeneratedCount) thread titles.")
            }
        }
    }
}

// MARK: - Additional Instructions View

private struct AdditionalInstructionsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var text: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section {
                CustomTextView(text: $text)
                    .frame(height: 300)
            } footer: {
                Text("These instructions will be added to the AI assistant's system prompt.")
            }
        }
        .navigationTitle("Additional Instructions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    settingsManager.userPrompt = text
                    settingsManager.saveNow()
                    dismiss()
                }
            }
        }
        .onAppear {
            text = settingsManager.userPrompt
        }
    }
}

// MARK: - Memories List View

private struct MemoriesListView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var selectedMemoryKey: String?
    
    private var sortedMemoryKeys: [String] {
        settingsManager.memories.keys.sorted()
    }
    
    var body: some View {
        Form {
            if settingsManager.memories.isEmpty {
                Section {
                    Text("No memories yet")
                        .foregroundColor(.secondary)
                        .italic()
                } footer: {
                    Text("The AI can add memories during conversations, or you can add them manually.")
                }
            } else {
                Section {
                    ForEach(sortedMemoryKeys, id: \.self) { key in
                        NavigationLink {
                            MemoryEditorView(
                                memoryKey: key,
                                onDelete: {
                                    settingsManager.deleteMemory(key: key)
                                }
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(key)
                                    .font(.headline)
                                
                                if let value = settingsManager.memories[key], !value.isEmpty {
                                    Text(value)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteMemories)
                }
            }
            
            Section {
                Button(action: addMemory) {
                    Label("Add Memory", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Memories")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedMemoryKey) { key in
            MemoryEditorView(
                memoryKey: key,
                onDelete: {
                    settingsManager.deleteMemory(key: key)
                    selectedMemoryKey = nil
                }
            )
        }
    }
    
    private func addMemory() {
        let newKey = settingsManager.addEmptyMemory()
        selectedMemoryKey = newKey
    }
    
    private func deleteMemories(at offsets: IndexSet) {
        let keysToDelete = offsets.map { sortedMemoryKeys[$0] }
        for key in keysToDelete {
            settingsManager.deleteMemory(key: key)
        }
    }
}

// MARK: - Memory Editor View

private struct MemoryEditorView: View {
    let memoryKey: String
    let onDelete: () -> Void
    
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var key: String = ""
    @State private var value: String = ""
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    private var isNewMemory: Bool {
        memoryKey.starts(with: "new_memory")
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Key", text: $key)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            } header: {
                Text("Key")
            } footer: {
                Text("A short identifier (e.g., 'user_name', 'favorite_color')")
            }
            
            Section {
                CustomTextView(text: $value)
                    .frame(height: 150)
            } header: {
                Text("Value")
            }
            
            if !isNewMemory {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Memory", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isNewMemory ? "New Memory" : "Edit Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    settingsManager.updateMemory(oldKey: memoryKey, newKey: key, value: value)
                    dismiss()
                }
                .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .confirmationDialog("Delete this memory?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            key = memoryKey
            value = settingsManager.memories[memoryKey] ?? ""
        }
    }
}

// MARK: - AI Tool Definition

private struct AIToolParameter: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let description: String
    let isRequired: Bool
}

private struct AIToolDefinition: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let parameters: [AIToolParameter]
    let isActive: Bool
    let inactiveReason: String?
    
    init(name: String, icon: String, description: String, parameters: [AIToolParameter], isActive: Bool = true, inactiveReason: String? = nil) {
        self.name = name
        self.icon = icon
        self.description = description
        self.parameters = parameters
        self.isActive = isActive
        self.inactiveReason = inactiveReason
    }
}

// MARK: - AI Tools List View

private struct AIToolsListView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    private var standardTools: [AIToolDefinition] {
        [
            AIToolDefinition(
                name: "take_photo",
                icon: "camera.fill",
                description: "Capture a photo from the user's smart glasses camera. Use this when the user asks about what they are seeing, looking at, or wants visual information about their surroundings.",
                parameters: []
            ),
            AIToolDefinition(
                name: "manage_memory",
                icon: "brain",
                description: "Store or update a memory about the user. Use when user shares personal info, preferences, or asks to remember something. Pass empty value to delete a memory.",
                parameters: [
                    AIToolParameter(
                        name: "key",
                        type: "string",
                        description: "Memory identifier in snake_case (e.g. 'user_name', 'preferred_language', 'favorite_food')",
                        isRequired: true
                    ),
                    AIToolParameter(
                        name: "value",
                        type: "string",
                        description: "Value to store. Pass empty string to delete the memory.",
                        isRequired: true
                    )
                ]
            )
        ]
    }
    
    var body: some View {
        List {
            Section {
                ForEach(standardTools) { tool in
                    AIToolRow(tool: tool)
                }
                
                // search_internet tool with NavigationLink for configuration
                NavigationLink {
                    SearchInternetToolView()
                } label: {
                    HStack(spacing: 8) {
                        Label {
                            Text("search_internet")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(settingsManager.isPerplexityConfigured ? .primary : .secondary)
                        } icon: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(settingsManager.isPerplexityConfigured ? .accentColor : .secondary)
                        }
                        
                        if !settingsManager.isPerplexityConfigured {
                            Text("Inactive")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                }
            } footer: {
                Text("Want more tools? Please contact the developer of this app.")
                    .padding(.top, 8)
            }
        }
        .navigationTitle("AI Tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Search Internet Tool View

private struct SearchInternetToolView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var apiKey: String = ""
    @FocusState private var isKeyFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section {
                Text("Search the internet for real-time information. Use when user asks about current events, news, weather, prices, sports scores, stock prices, or any question requiring up-to-date information from the web.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } header: {
                Text("Description")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("query")
                            .font(.footnote)
                            .fontWeight(.medium)
                        
                        Text("string")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        
                        Text("required")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                    
                    Text("Search query in natural language, one sentence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Parameters")
            }
            
            Section {
                SecureField("Perplexity API Key", text: $apiKey)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isKeyFieldFocused)
            } header: {
                Text("API Key")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if apiKey.isEmpty {
                        Text("Optional. Add API key to enable web search.")
                            .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Tool enabled")
                                .foregroundColor(.green)
                        }
                    }
                    Text("Get your API key at perplexity.ai/settings/api")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            isKeyFieldFocused = false
        }
        .navigationTitle("search_internet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    settingsManager.perplexityAPIKey = apiKey
                    settingsManager.saveNow()
                    dismiss()
                }
            }
        }
        .onAppear {
            apiKey = settingsManager.perplexityAPIKey
        }
    }
}

// MARK: - AI Tool Row

private struct AIToolRow: View {
    let tool: AIToolDefinition
    @State private var isExpanded: Bool = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                // Description
                Text(tool.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Parameters
                if !tool.parameters.isEmpty {
                    Divider()
                    
                    Text("Parameters")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ForEach(tool.parameters) { param in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(param.name)
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text(param.type)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                                
                                if param.isRequired {
                                    Text("required")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text(param.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Divider()
                    
                    Text("No parameters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding(.vertical, 8)
            // Inactive reason
            if !tool.isActive, let reason = tool.inactiveReason {
                Divider()
                
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Label {
                    Text(tool.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(tool.isActive ? .primary : .secondary)
                } icon: {
                    Image(systemName: tool.icon)
                        .foregroundColor(tool.isActive ? .accentColor : .secondary)
                }
                
                if !tool.isActive {
                    Text("Inactive")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
        }
    }
}

// MARK: - Models List View

private struct ModelsListView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        List {
            Section {
                NavigationLink {
                    OpenAIModelView()
                } label: {
                    HStack {
                        Label("OpenAI", systemImage: "cpu")
                        Spacer()
                        if !settingsManager.isOpenAIConfigured {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            } footer: {
                Text("Configure API keys for AI models used by the voice assistant.")
            }
        }
        .navigationTitle("Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - OpenAI Model View

private struct OpenAIModelView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var apiKey: String = ""
    @FocusState private var isKeyFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section {
                SecureField("API Key", text: $apiKey)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isKeyFieldFocused)
            } header: {
                Text("API Key")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if apiKey.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Required for voice conversations")
                                .foregroundColor(.red)
                        }
                    }
                    Text("Get your API key at platform.openai.com/api-keys")
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This API key is used for:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Voice conversations (Realtime API)", systemImage: "waveform")
                        Label("Thread title generation", systemImage: "text.quote")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            } header: {
                Text("Usage")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            isKeyFieldFocused = false
        }
        .navigationTitle("OpenAI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    settingsManager.openAIAPIKey = apiKey
                    settingsManager.saveNow()
                    dismiss()
                }
            }
        }
        .onAppear {
            apiKey = settingsManager.openAIAPIKey
        }
    }
}

// MARK: - Permissions View

private struct PermissionsView: View {
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    private var requiredPermissions: [PermissionType] {
        [.bluetooth, .microphone]
    }
    
    private var optionalPermissions: [PermissionType] {
        PermissionType.allCases.filter { !$0.isRequired }
    }
    
    var body: some View {
        List {
            Section {
                ForEach(requiredPermissions) { permission in
                    NavigationLink {
                        PermissionDetailView(permission: permission)
                    } label: {
                        PermissionRow(
                            permission: permission,
                            status: permissionsManager.status(for: permission)
                        )
                    }
                }
            } header: {
                Text("Required")
            }
            
            Section {
                ForEach(optionalPermissions) { permission in
                    NavigationLink {
                        PermissionDetailView(permission: permission)
                    } label: {
                        PermissionRow(
                            permission: permission,
                            status: permissionsManager.status(for: permission)
                        )
                    }
                }
            } header: {
                Text("Optional")
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            permissionsManager.refreshAll()
        }
        .onChange(of: scenePhase) {
            // Refresh when returning from Settings app
            if scenePhase == .active {
                permissionsManager.refreshAll()
            }
        }
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let permission: PermissionType
    let status: PermissionStatus
    
    private var statusColor: Color {
        switch status {
        case .notDetermined: return .orange
        case .authorized: return .green
        case .denied: return .red
        case .restricted: return .gray
        case .limited: return .yellow
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: permission.icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.rawValue)
                    .font(.body)
                
                HStack(spacing: 4) {
                    Text(status.rawValue)
                        .font(.caption)
                        .foregroundColor(statusColor)
                    
                    if let level = permission.accessLevel,
                       status == .authorized || status == .limited {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(level)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: status.systemImage)
                .foregroundColor(statusColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Permission Detail View

private struct PermissionDetailView: View {
    let permission: PermissionType
    
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPhotoLibraryExplanation: Bool = false
    @State private var showLocationExplanation: Bool = false
    
    private var status: PermissionStatus {
        permissionsManager.status(for: permission)
    }
    
    private var statusColor: Color {
        switch status {
        case .notDetermined: return .orange
        case .authorized: return .green
        case .denied: return .red
        case .restricted: return .gray
        case .limited: return .yellow
        }
    }
    
    var body: some View {
        Form {
            // Status Section
            Section {
                HStack {
                    Image(systemName: status.systemImage)
                        .font(.title)
                        .foregroundColor(statusColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(status.rawValue)
                            .font(.headline)
                            .foregroundColor(statusColor)
                        
                        if let level = permission.accessLevel,
                           status == .authorized || status == .limited {
                            Text("Access Level: \(level)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 8)
                }
                .padding(.vertical, 8)
            }
            
            // Description Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if status == .authorized || status == .limited {
                        Text(permission.descriptionWhenAllowed)
                            .font(.body)
                            .foregroundColor(.primary)
                    } else {
                        Text(permission.descriptionWhenDenied)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    
                    if let note = permission.withoutPermissionNote {
                        Text(note)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(!permission.isRequired ? "About This Permission" : (status == .authorized || status == .limited ? "What This Enables" : "What You're Missing"))
            }
            
            // Action Section
            Section {
                if status == .notDetermined {
                    Button {
                        requestPermission()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text("Request Permission")
                        }
                    }
                } else if status == .denied || status == .restricted {
                    Button {
                        permissionsManager.openAppSettings()
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                    }
                } else if status == .authorized || status == .limited {
                    Button {
                        permissionsManager.openAppSettings()
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Manage in Settings")
                        }
                    }
                    
                    Text("To revoke this permission, go to Settings and disable it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Actions")
            } footer: {
                if status == .notDetermined {
                    Text("Tap to show the system permission dialog.")
                } else if status == .denied || status == .restricted {
                    Text("iOS requires you to change this permission in Settings.")
                }
            }
        }
        .navigationTitle(permission.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            permissionsManager.refreshAll()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                permissionsManager.refreshAll()
            }
        }
        .alert("Photo Library Access", isPresented: $showPhotoLibraryExplanation) {
            Button("Continue") {
                permissionsManager.requestPhotoLibrary()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This app requests ADD-ONLY access to your Photo Library.\n\nThe app will NOT be able to see or access any existing photos or videos. It also won't see photos or videos created by other apps.\n\nThis permission is only needed to save photos and videos captured from your glasses.")
        }
        .alert("Location Access", isPresented: $showLocationExplanation) {
            Button("Continue") {
                permissionsManager.requestLocation()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("If you allow location access, AI will receive your city and country to provide context-aware responses (weather, local recommendations, time zone).\n\nIf you don't allow it, everything will work the same — AI just won't know your location unless you tell it yourself.")
        }
    }
    
    private func requestPermission() {
        switch permission {
        case .location:
            // Show explanation alert first
            showLocationExplanation = true
        case .microphone:
            permissionsManager.requestMicrophone()
        case .photoLibrary:
            // Show explanation alert first
            showPhotoLibraryExplanation = true
        case .bluetooth:
            permissionsManager.requestBluetooth()
        }
    }
}

// MARK: - Push Notification Test View

private struct PushNotificationTestView: View {
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        Form {
            // Status Section
            Section {
                HStack {
                    Text("Audio Output")
                    Spacer()
                    Text(notificationManager.getAudioOutputDescription())
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Routed to Glasses")
                    Spacer()
                    Image(systemName: notificationManager.audioRoutedToGlasses ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(notificationManager.audioRoutedToGlasses ? .green : .orange)
                }

                if notificationManager.isSpeaking {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Speaking...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Audio Route")
            } footer: {
                if !notificationManager.audioRoutedToGlasses {
                    Text("Connect your Meta glasses via Bluetooth to hear notifications through them. Otherwise, audio will play through your device speaker.")
                }
            }

            // Test Buttons Section
            Section {
                Button {
                    notificationManager.sendTestNotification()
                } label: {
                    HStack {
                        Label("Send Test Notification", systemImage: "bell")
                        Spacer()
                        if notificationManager.isSpeaking {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(notificationManager.isSpeaking)

                Button {
                    notificationManager.sendImportantNotification()
                } label: {
                    HStack {
                        Label("Simulate Job Offer Alert", systemImage: "briefcase.fill")
                        Spacer()
                        if notificationManager.isSpeaking {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(notificationManager.isSpeaking)

                if notificationManager.isSpeaking {
                    Button(role: .destructive) {
                        notificationManager.stopSpeaking()
                    } label: {
                        Label("Stop Speaking", systemImage: "stop.fill")
                    }
                }
            } header: {
                Text("Test Push Notifications")
            } footer: {
                Text("These buttons simulate notifications being pushed to your glasses. The audio will play through your glasses speakers if connected via Bluetooth.")
            }

            // Custom Message Section
            Section {
                CustomNotificationView()
            } header: {
                Text("Custom Message")
            }

            // Last Notification
            if !notificationManager.lastNotification.isEmpty {
                Section {
                    Text(notificationManager.lastNotification)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Last Notification")
                }
            }

            // Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("This is a proof-of-concept for pushing notifications to your glasses via Bluetooth audio.")
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }

                    Text("Future integration with Clawdbot would enable:\n• Important email alerts\n• Message notifications from any platform\n• Priority filtering (job offers, emergencies)\n• Cross-platform AI assistant access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Push Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notificationManager.checkAudioRoute()
        }
    }
}

// MARK: - Custom Notification View

private struct CustomNotificationView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var customMessage: String = ""
    @FocusState private var isMessageFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            TextField("Type a message to push to glasses...", text: $customMessage, axis: .vertical)
                .lineLimit(2...4)
                .focused($isMessageFieldFocused)

            Button {
                if !customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notificationManager.pushNotification(customMessage)
                    customMessage = ""
                    isMessageFieldFocused = false
                }
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Push to Glasses")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || notificationManager.isSpeaking)
        }
    }
}

#Preview {
    SettingsView(glassesManager: GlassesManager())
}
