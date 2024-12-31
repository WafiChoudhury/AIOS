import SwiftUI

struct InputView: View {
    @Binding var inputText: String
    let isLoading: Bool
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 12) {
                TextField("Ask anything", text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.custom("Menlo", size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .foregroundColor(.black) // Ensures the text is always black
                    .cornerRadius(8)
                    .onSubmit(onSend)
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(inputText.isEmpty ? .gray : .black)
                }
                
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
        }
        .background(Color.black)
    }
}
