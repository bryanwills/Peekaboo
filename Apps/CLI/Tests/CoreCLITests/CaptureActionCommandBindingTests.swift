import Commander
import Testing
@testable import PeekabooCLI

struct CaptureActionCommandBindingTests {
    @Test
    func `Capture action command binding`() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "mode": ["area"],
                "region": ["0,0,320,240"],
                "captureEngine": ["cg"],
                "durationLimit": ["5"],
                "preRollMs": ["100"],
                "postRollMs": ["250"],
                "actionTimeout": ["3"],
                "path": ["/tmp/action-capture"],
                "command": ["echo", "hello", "--flag"],
            ],
            flags: ["highlightChanges"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: CaptureActionCommand.self,
            parsedValues: parsed
        )
        #expect(command.mode == "area")
        #expect(command.region == "0,0,320,240")
        #expect(command.captureEngine == "cg")
        #expect(command.durationLimit == 5)
        #expect(command.preRollMs == 100)
        #expect(command.postRollMs == 250)
        #expect(command.actionTimeout == 3)
        #expect(command.path == "/tmp/action-capture")
        #expect(command.command == ["echo", "hello", "--flag"])
        #expect(command.highlightChanges == true)
    }

    @Test
    func `Capture action commander signature captures remaining command`() {
        let signature = CaptureActionCommand.commanderSignature()
        #expect(signature.options.contains { $0.label == "durationLimit" })
        #expect(signature.options.contains { $0.label == "command" && $0.parsing == .remaining })
        #expect(!signature.options.contains { $0.label == "duration" })
    }
}
