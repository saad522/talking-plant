import SwiftUI

public struct PlantHistoryLoadingView: View {
    init() {}

    public var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
