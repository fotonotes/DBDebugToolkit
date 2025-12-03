import SwiftUI
import UIKit

// SwiftUI wrapper for the UIKit-based DBConsoleViewController
struct ConsoleViewControllerWrapper: UIViewControllerRepresentable {
    let consoleOutputCaptor: DBConsoleOutputCaptor
    let deviceInfoProvider: DBDeviceInfoProvider

    func makeUIViewController(context: Context) -> DBConsoleViewController {
        return DBConsoleViewController(
            consoleOutputCaptor: consoleOutputCaptor,
            deviceInfoProvider: deviceInfoProvider
        )
    }

    func updateUIViewController(_ uiViewController: DBConsoleViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Legacy SwiftUI Console View (kept for reference, not used)

struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.consoleLines.isEmpty {
                        Text("No console output yet")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(Array(viewModel.consoleLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                }
            }
        }
        .navigationBarTitle("Console")
        .navigationBarItems(trailing: navigationBarItems())
    }
}

private extension ConsoleView {
    func navigationBarItems() -> some View {
        HStack(alignment: .center, spacing: 20) {
            Button(
                action: viewModel.shareConsoleOutput,
                label: {
                    Image(systemName: "square.and.arrow.up")
                }
            )

            Button(
                action: viewModel.pauseConsoleOutput,
                label: {
                    let imageName = viewModel.isConsoleOutputPause ? "pause.circle.fill" : "pause.circle"
                    Image(systemName: imageName)
                }
            )

            Button(
                action: viewModel.clearConsoleOutput,
                label: {
                    Image(systemName: "trash")
                }
            )
        }
    }
}
