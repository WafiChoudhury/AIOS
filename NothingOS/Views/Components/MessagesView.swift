import SwiftUI

struct MessagesView: View {
    let messages: [Message]
    let isLoading: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                    
                    if isLoading {
                        LoadingIndicator()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
        }
        .background(Color.black)
    }
}
