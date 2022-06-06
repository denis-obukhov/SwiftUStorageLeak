//
//  ContentView.swift
//  SwiftUStorageLeak
//
//  Created by Denis Obukhov on 06.06.2022.
//

import SwiftUI

// Use Case: collect actions to perform menu commands
// 
// Issue: Storing DetailsView context ( "isTakingSnapshot = true" ) leads to a memory leak
//        All view associated memory storage doesn't get deallocated even though a view itself no longer exist
// Solution: move stored context to ViewModel and capture it as a weak reference

// MARK: - App

@main
struct SwiftUStorageLeakApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands(content: AppCommands.init)
    }
}

// MARK: - Views

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                ForEach(0..<5, id: \.self) { item in
                    NavigationLink("Go to details #\(item)") {
                        DetailsView(item: item)
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.largeTitle)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

final class DetailsViewModel: ObservableObject {
//    @Published var isTakingSnapshot = false // ✅ SOLUTION
    init() { print("☀️ DetailViewModel init") }
    deinit { print("💭 DetailViewModel deinit") }
}

struct DetailsView: View {
    let item: Int
    @StateObject private var viewModel = DetailsViewModel()
    @State private var isTakingSnapshot = false
    
    var body: some View {
        Text("Details #\(item)")
            .font(.largeTitle)
//          ⛔️ WRONG ATTEMPT:
            .sheet(isPresented: $isTakingSnapshot) {
                Text("Snapshot #\(item)")
            }
            .appCommand(.takeSnapshot) {
                isTakingSnapshot = true // ⚠️ Capturing and saving DetailsView's context produces a memory leak
                // DetailsView is a struct and there's no way to capture it as a weak reference
                // A solution could be moving isTakingSnapshot var to view model as @Published property
                // and capturing DetailsViewModel by a weak reference
            }
        
//            ✅ SOLUTION:
//            .appCommand(.takeSnapshot) { [weak viewModel] in
//                viewModel?.isTakingSnapshot = true
//            }
//            .sheet(isPresented: $viewModel.isTakingSnapshot) {
//                Text("Snapshot #\(item)")
//            }
    }
}

// MARK: - Commands

enum AppCommandItemType: CaseIterable {
    case takeSnapshot, previous, next
}

struct AppCommandItem {
    let type: AppCommandItemType
    var action: () -> Void
    var isActive = true
}

extension AppCommandItemType {
    var focusedValueKeyPath: WritableKeyPath<FocusedValues, AppCommandItem?> {
        switch self {
        case .takeSnapshot:
            return \.takeSnapshotCommand
        case .previous:
            return \.previousCommand
        case .next:
            return \.nextCommand
        }
    }
}

struct TakeSnapshotCommandKey: FocusedValueKey {
    typealias Value = AppCommandItem
}

struct NextCommandCommandKey: FocusedValueKey {
    typealias Value = AppCommandItem
}

struct PreviousCommandCommandKey: FocusedValueKey {
    typealias Value = AppCommandItem
}

extension FocusedValues {
    var takeSnapshotCommand: AppCommandItem? {
        get { self[TakeSnapshotCommandKey.self] }
        set { self[TakeSnapshotCommandKey.self] = newValue }
    }
  
    var previousCommand: AppCommandItem? {
        get { self[PreviousCommandCommandKey.self] }
        set { self[PreviousCommandCommandKey.self] = newValue }
    }
    
    var nextCommand: AppCommandItem? {
        get { self[NextCommandCommandKey.self] }
        set { self[NextCommandCommandKey.self] = newValue }
    }
}

// Convenient extension
extension View {
    func appCommand(
        _ type: AppCommandItemType,
        action: @escaping () -> Void,
        isActive: Bool = true
    ) -> some View {
        focusedSceneValue(
            type.focusedValueKeyPath,
            AppCommandItem(
                type: type,
                action: action,
                isActive: isActive
            )
        )
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.previousCommand) var previousCommand
    @FocusedValue(\.nextCommand) var nextCommand
    @FocusedValue(\.takeSnapshotCommand) var takeSnapshotCommand
    
    var body: some Commands {
        CommandMenu("Actions") {
            commandButton("Next", command: nextCommand)
                .keyboardShortcut(.rightArrow, modifiers: .command)
            
            commandButton("Previous", command: previousCommand)
                .keyboardShortcut(.leftArrow, modifiers: .command)
  
            commandButton("Make a Snapshot", command: takeSnapshotCommand)
                .keyboardShortcut("D", modifiers: .command)
        }
    }
    
    @ViewBuilder
    private func commandButton(_ name: String, command: AppCommandItem?) -> some View {
        if let command = command {
            Button(name, action: command.action)
                .disabled(command.isActive != true)
        }
    }
}
