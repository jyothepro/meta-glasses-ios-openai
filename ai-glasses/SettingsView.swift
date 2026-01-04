//
//  SettingsView.swift
//  ai-glasses
//
//  Created by AI Assistant on 04/01/2026.
//

import SwiftUI
import UIKit
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ai-glasses", category: "SettingsView")

// Wrapper for memory key to use with sheet(item:)
private struct MemoryItem: Identifiable {
    let id: String
    let value: String
}

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
            // Place cursor at the end
            let endPosition = textView.endOfDocument
            textView.selectedTextRange = textView.textRange(from: endPosition, to: endPosition)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var glassesManager: GlassesManager
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var userPrompt: String = ""
    @State private var selectedMemory: MemoryItem?
    
    var body: some View {
        NavigationStack {
            Form {
                // Developer Section
                Section {
                    NavigationLink {
                        GlassesTab(glassesManager: glassesManager)
                    } label: {
                        Label("Glasses", systemImage: "eyeglasses")
                    }
                } header: {
                    Text("Developer")
                }
                
                // User Prompt Section
                Section {
                    CustomTextView(text: $userPrompt)
                        .frame(height: 120)
                        .onChange(of: userPrompt) { _, newValue in
                            settingsManager.userPrompt = newValue
                        }
                } header: {
                    Text("Additional Instructions")
                } footer: {
                    Text("These instructions will be added to the AI assistant's system prompt.")
                }
                
                // Memories Section
                Section {
                    if settingsManager.memories.isEmpty {
                        Text("No memories yet")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(sortedMemoryKeys, id: \.self) { key in
                            MemoryRowView(
                                key: key,
                                value: settingsManager.memories[key] ?? "",
                                onTap: {
                                    selectedMemory = MemoryItem(
                                        id: key,
                                        value: settingsManager.memories[key] ?? ""
                                    )
                                }
                            )
                        }
                        .onDelete(perform: deleteMemories)
                    }
                    
                    Button(action: addMemory) {
                        Label("Add Memory", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Memories")
                } footer: {
                    Text("The AI can add, update, or delete memories during conversations. You can also manage them here.")
                }
                
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
            .navigationTitle("Settings")
            .onAppear {
                userPrompt = settingsManager.userPrompt
            }
            .onDisappear {
                settingsManager.saveNow()
            }
            .sheet(item: $selectedMemory) { memory in
                MemoryEditorView(
                    originalKey: memory.id,
                    originalValue: memory.value,
                    onSave: { newKey, newValue in
                        settingsManager.updateMemory(oldKey: memory.id, newKey: newKey, value: newValue)
                        selectedMemory = nil
                    },
                    onCancel: {
                        selectedMemory = nil
                    }
                )
            }
        }
    }
    
    private var sortedMemoryKeys: [String] {
        settingsManager.memories.keys.sorted()
    }
    
    private func addMemory() {
        let newKey = settingsManager.addEmptyMemory()
        selectedMemory = MemoryItem(id: newKey, value: "")
    }
    
    private func deleteMemories(at offsets: IndexSet) {
        let keysToDelete = offsets.map { sortedMemoryKeys[$0] }
        for key in keysToDelete {
            settingsManager.deleteMemory(key: key)
        }
    }
}

// MARK: - Memory Row View

private struct MemoryRowView: View {
    let key: String
    let value: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(key)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !value.isEmpty {
                        Text(value)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Memory Editor View

private struct MemoryEditorView: View {
    let originalKey: String
    let originalValue: String
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var key: String = ""
    @State private var value: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Key", text: $key)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Key")
                } footer: {
                    Text("A short identifier for this memory (e.g., 'user_name', 'favorite_color')")
                }
                
                Section {
                    CustomTextView(text: $value)
                        .frame(height: 100)
                } header: {
                    Text("Value")
                } footer: {
                    Text("The information to remember")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
            .navigationTitle(originalKey.starts(with: "new_memory") ? "New Memory" : "Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(key, value)
                    }
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                key = originalKey
                value = originalValue
            }
        }
    }
}

#Preview {
    SettingsView(glassesManager: GlassesManager())
}
