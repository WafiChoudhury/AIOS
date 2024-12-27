import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            Text(message.content)
                .textSelection(.enabled)
                .font(.custom("Monaco", size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(message.isUser ? Color.gray.opacity(0.3) : Color.gray)
                .foregroundColor(message.isUser ? .white : .black)
                .cornerRadius(16)
                .frame(alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
    }
}
