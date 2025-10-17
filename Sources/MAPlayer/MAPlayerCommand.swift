// ABOUTME: Root command for ma-player CLI with subcommand routing
// ABOUTME: Configures ArgumentParser with all available subcommands

import ArgumentParser

@main
struct MAPlayerCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ma-player",
        abstract: "Music Assistant audio player CLI",
        version: "1.0.0",
        subcommands: [
            PlayCommand.self,
            ControlCommand.self,
        ]
    )
}
