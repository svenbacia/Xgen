/**
 *  Xgen
 *  Copyright (c) John Sundell 2017
 *  Licensed under the MIT license. See LICENSE file.
 */

import Foundation
import XCTest
import Xgen
import Files
import ShellOut

// MARK: - Test case

class XgenTests: XCTestCase {
    var folder: Folder!

    // MARK: - XCTestCase

    override func setUp() {
        super.setUp()
        folder = try! FileSystem().temporaryFolder.createSubfolderIfNeeded(withName: "XgenTests")
        try! folder.empty()
    }

    // MARK: - Tests

    func testGeneratingEmptyWorkspace() throws {
        let workspace = Workspace(path: folder.path + "Workspace")
        try workspace.generate()

        let workspaceFolder = try folder.subfolder(named: "Workspace.xcworkspace")
        let contentsFile = try workspaceFolder.file(named: "Contents.xcworkspacedata")
        let xml = try XMLDocument(data: contentsFile.read(), options: [])
        XCTAssertGreaterThan(xml.childCount, 0)
    }

    func testGeneratingAndBuildingWorkspace() throws {
        // In this test we generate & build a workspace containing a Xcode
        // project generated by the Swift Package Manager, to verify that the
        // generated workspace has a correct layout and is Xcode compatible

        // Start by generating the Xcode project
        let projectFolder = try folder.createSubfolder(named: "Project")
        let projectCommand = "swift package init && swift package generate-xcodeproj"
        try projectFolder.moveToAndPerform(command: projectCommand)

        // Generate workspace
        let workspace = Workspace(path: folder.path + "Workspace.xcworkspace")
        workspace.addProject(at: folder.path + "Project/Project.xcodeproj/")
        try workspace.generate()

        // Build using xcodebuild
        let buildCommand = "xcodebuild -workspace Workspace.xcworkspace -scheme Project-Package"
        let buildOutput = try folder.moveToAndPerform(command: buildCommand)
        XCTAssertTrue(buildOutput.contains("** BUILD SUCCEEDED **"))
    }

    func testGeneratingPlayground() throws {
        let code = "import Foundation\n\nprint(\"Hello world\")"
        let playground = Playground(
            path: folder.path + "Playground",
            platform: .macOS,
            code: code
        )

        try playground.generate()

        let playgroundFolder = try folder.subfolder(named: "Playground.playground")

        let codeFile = try playgroundFolder.file(named: "Contents.swift")
        try XCTAssertEqual(codeFile.readAsString(), code)

        let contentsFile = try playgroundFolder.file(named: "contents.xcplayground")
        let xml = try XMLDocument(data: contentsFile.read(), options: [])
        XCTAssertGreaterThan(xml.childCount, 0)
        XCTAssertTrue(try contentsFile.readAsString().contains(playground.platform.rawValue))
    }

    func testChangingPlaygroundPlatformUpdatesDefaultCode() throws {
        let playground = Playground(path: folder.path + "Playground")
        XCTAssertEqual(playground.platform, .iOS)

        playground.platform = .macOS
        try playground.generate()

        let codeFile = try folder.file(atPath: "Playground.playground/Contents.swift")
        try XCTAssertTrue(codeFile.readAsString().contains("import Cocoa"))
    }

    func testAddingGeneratingPlaygroundWithinWorkspace() throws {
        let workspace = Workspace(path: folder.path + "Workspace")
        workspace.addPlayground(named: "NewPlayground")
        try workspace.generate()

        let workspaceFolder = try folder.subfolder(named: "Workspace.xcworkspace")
        let playgroundFolder = try workspaceFolder.subfolder(named: "NewPlayground.playground")
        let contentsFile = try workspaceFolder.file(named: "Contents.xcworkspacedata")
        XCTAssertTrue(try contentsFile.readAsString().contains(playgroundFolder.path))
    }
}

// MARK: - Extensions

private extension Folder {
    @discardableResult func moveToAndPerform(command: String) throws -> String {
        return try shellOut(to: "cd \(path) && \(command)")
    }
}
