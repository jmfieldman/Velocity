//
//  Process+Extensions.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation

public extension Process {
  struct ExecutionResults {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
  }

  static func execute(
    command: String,
    workingDirectory: URL? = nil,
    outputStdoutWhileRunning: Bool = false,
    outputStderrWhileRunning: Bool = false
  ) -> ExecutionResults {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]

    if let workingDirectory {
      task.currentDirectoryURL = workingDirectory
    }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    task.standardOutput = stdoutPipe
    task.standardError = stderrPipe

    var stdoutData = Data()
    var stderrData = Data()

    let group = DispatchGroup()

    group.enter()
    stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      if data.isEmpty {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        group.leave()
      } else {
        stdoutData.append(data)
        if outputStdoutWhileRunning {
          fputs(String(data: data, encoding: .utf8), stdout)
        }
      }
    }

    group.enter()
    stderrPipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      if data.isEmpty {
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        group.leave()
      } else {
        stderrData.append(data)
        if outputStderrWhileRunning {
          fputs(String(data: data, encoding: .utf8), stderr)
        }
      }
    }

    task.launch()
    group.wait()
    task.waitUntilExit()

    return ExecutionResults(
      exitCode: task.terminationStatus,
      stdout: String(data: stdoutData, encoding: .utf8)!,
      stderr: String(data: stderrData, encoding: .utf8)!
    )
  }

  static func shellOutput(_ command: String) -> String {
    Process.execute(command: command).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
