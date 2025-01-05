// Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var fileContextManager = FileContextManager()

    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            
            MessagesView(
                messages: viewModel.messages,
                isLoading: viewModel.isLoading
            )
            
            InputView(
                inputText: $viewModel.inputText,
                isLoading: viewModel.isLoading,
                onSend: viewModel.sendMessage
            )
        }
        .background(Color.black)
    }
}

#Preview {
    ContentView()
}
