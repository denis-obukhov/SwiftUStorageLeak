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
// Conditions: NavigationView with StackNavigationViewStyle
// Solution 1: use @FocusedValue and .focusedSceneValue() to control Commands
// Solution 2: move stored context to ViewModel and capture it as a weak reference

// MARK: - App

@main
struct SwiftUStorageLeakApp: App {
    @State var appCommands: [AppCommandItemType: AppCommandItem] = [:]
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onPreferenceChange(AppCommandItemKey.self) { preference in
                    AppCommandItemType.allCases.forEach { commandType in
                        let lastAction = preference.last(where: {
                            $0.type == commandType
                        })
                        appCommands[commandType] = lastAction
                    }
                }
        }
        .commands {
            CommandMenu("Actions") {
                Button("Take a snapshot") {
                    appCommands[.takeSnapshot]?.action?()
                }
                .keyboardShortcut("D", modifiers: .command)
            }
        }
    }
}

// MARK: - Views

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                ForEach(0..<5, id: \.self) { item in
                    NavigationLink {
                        DetailsView(item: item)
                    } label: {
                        Text("Go to details #\(item)")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

final class DetailsViewModel: ObservableObject {
    init() { print("☀️ init") }
    deinit { print("💭 deinit") }
}

struct DetailsView: View {
    let item: Int
    @StateObject private var viewModel = DetailsViewModel()
    @State private var isTakingSnapshot = false
    
    var body: some View {
        Text("Details #\(item)")
            .sheet(isPresented: $isTakingSnapshot) {
                Text("Snapshot #\(item)")
            }
            .appCommand(.takeSnapshot, id: String(item)) {
                isTakingSnapshot = true // ⚠️ Capturing and saving DetailsView's context produces a memory leak
                // DetailsView is a struct and there's no way to capture it as a weak reference
                // A solution could be moving isTakingSnapshot var to view model as @Published property
                // and capturing DetailsViewModel by a weak reference
            }
    }
}

// MARK: - Preferences

enum AppCommandItemType: Equatable, CaseIterable, Hashable {
    case takeSnapshot, previous, next
}

struct AppCommandItem: Identifiable, Equatable {
    let type: AppCommandItemType
    var action: (() -> Void)? = nil
    let id: String // Provide an ID in order to make onPreferenceChange method get called
    
    static func == (lhs: AppCommandItem, rhs: AppCommandItem) -> Bool {
        lhs.type == rhs.type && lhs.id == rhs.id
    }
}

struct AppCommandItemKey: PreferenceKey {
    typealias Value = [AppCommandItem]
    static var defaultValue: Value = []
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = value + nextValue()
    }
}

// Convenient extension
extension View {
    func appCommand( _ type: AppCommandItemType, id: String, action: (() -> Void)?) -> some View {
        preference(key: AppCommandItemKey.self, value: [AppCommandItem(type: type, action: action, id: id)])
    }
}
