final class ConsoleViewModel: NSObject, ObservableObject {
    let consoleOutputCaptor: DBConsoleOutputCaptor
    let deviceInfoProvider: DBDeviceInfoProvider
    @Published var consoleOutput: String
    @Published var consoleLines: [String] = []
    @Published var isConsoleOutputPause: Bool = false

    private var updateWorkItem: DispatchWorkItem?
    private let updateDebounceInterval: TimeInterval = 0.1 // 100ms debounce
    private let maxLines = 2000 // Maximum number of lines to keep

    init(
        consoleOutputCaptor: DBConsoleOutputCaptor,
        deviceInfoProvider: DBDeviceInfoProvider
    ) {
        self.consoleOutputCaptor = consoleOutputCaptor
        self.deviceInfoProvider = deviceInfoProvider
        self.consoleOutput = consoleOutputCaptor.consoleOutput
        self.consoleLines = Self.splitIntoLines(consoleOutputCaptor.consoleOutput, maxLines: maxLines)
        super.init()
        self.consoleOutputCaptor.delegate = self
    }

    private static func splitIntoLines(_ output: String, maxLines: Int) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        if lines.count > maxLines {
            return Array(lines.suffix(maxLines))
        }
        return lines
    }

    func pauseConsoleOutput() {
        isConsoleOutputPause.toggle()
    }

    func clearConsoleOutput() {
        consoleOutput = ""
        consoleLines = []
        consoleOutputCaptor.clearConsoleOutput()
    }

    func shareConsoleOutput() {
        let content = """
        Device model: \(deviceInfoProvider.deviceModel() ?? "unknown"))
        System version: \(deviceInfoProvider.systemVersion() ?? "unknown")
        Console output:\(consoleOutput)
        """

        let activityVC = UIActivityViewController(activityItems: [content], applicationActivities: nil)
        let rootViewController = UIWindow.keyWindow?.rootViewController
        if let presentedViewController = rootViewController?.presentedViewController {
            presentedViewController.present(activityVC, animated: true)
        } else {
            rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - DBConsoleOutputCaptorDelegate

extension ConsoleViewModel: DBConsoleOutputCaptorDelegate {
    func consoleOutputCaptorDidUpdateOutput(_ consoleOutputCaptor: DBConsoleOutputCaptor!) {
        guard !isConsoleOutputPause else {
            return
        }

        // Cancel previous update if it hasn't executed yet
        updateWorkItem?.cancel()

        // Create a new work item with debounce
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.consoleOutput = consoleOutputCaptor.consoleOutput
            self.consoleLines = Self.splitIntoLines(consoleOutputCaptor.consoleOutput, maxLines: self.maxLines)
        }

        updateWorkItem = workItem

        // Execute the update after debounce interval
        DispatchQueue.main.asyncAfter(deadline: .now() + updateDebounceInterval, execute: workItem)
    }

    func consoleOutputCaptor(_ consoleOutputCaptor: DBConsoleOutputCaptor!, didSetEnabled enabled: Bool) {

    }
}
