//
//  Process+Extensions.swift
//  Copyright © 2021 Jason Fieldman.
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

    task.launch()

    var stdoutData = Data()
    var stderrData = Data()

    let stdoutHandle = stdoutPipe.fileHandleForReading
    let stderrHandle = stderrPipe.fileHandleForReading

    while task.isRunning {
      let moreStdOutData = try! stdoutHandle.read(upToCount: 10240)
      let moreStdErrData = try! stderrHandle.read(upToCount: 10240)

      stdoutData.append(moreStdOutData ?? Data())
      stderrData.append(moreStdErrData ?? Data())

      if let moreStdErrData, outputStderrWhileRunning, !moreStdErrData.isEmpty {
        fputs(String(data: moreStdErrData, encoding: .utf8), stderr)
      }

      if let moreStdOutData, outputStdoutWhileRunning, !moreStdOutData.isEmpty {
        fputs(String(data: moreStdOutData, encoding: .utf8), stdout)
      }

      Thread.sleep(forTimeInterval: 0.05)
    }

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
