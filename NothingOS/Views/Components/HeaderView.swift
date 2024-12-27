import SwiftUI

struct HeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .font(.system(size: 25))
            Text("Carry")
                .font(.custom("Menlo", size: 25))
            Spacer()
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
    }
}
