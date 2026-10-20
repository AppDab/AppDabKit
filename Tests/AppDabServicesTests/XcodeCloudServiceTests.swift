@testable import AppDabServices
import BagbutikXcodeCloudModels
import Foundation
import Testing

struct XcodeCloudServiceTests {
    @Test func startRequestUsesAppleResourceRelationshipsAndPreservesFalse() throws {
        let request = XcodeCloudService.startBuildRequest(.init(workflowID: "workflow-1", sourceBranchOrTagID: "reference-1", clean: false))
        #expect(request.path == "/v1/ciBuildRuns")
        #expect(request.method.rawValue == "POST")
        let body = try #require(request.requestBody)
        let payload = try JSONDecoder().decode(JSONValue.self, from: body.getJsonData())
        let data = try #require(payload.objectValue?["data"]?.objectValue)
        #expect(data["type"] == .string("ciBuildRuns"))
        #expect(data["attributes"] == .object(["clean": .bool(false)]))
        #expect(data["relationships"] == .object([
            "workflow": .object(["data": .object(["type": .string("ciWorkflows"), "id": .string("workflow-1")])]),
            "sourceBranchOrTag": .object(["data": .object(["type": .string("scmGitReferences"), "id": .string("reference-1")])]),
        ]))
        let defaults = try #require(XcodeCloudService.startBuildRequest(.init(workflowID: "workflow-1")).requestBody)
        let defaultPayload = try JSONDecoder().decode(JSONValue.self, from: defaults.getJsonData())
        let defaultData = try #require(defaultPayload.objectValue?["data"]?.objectValue)
        #expect(defaultData["attributes"] == nil)
        #expect(defaultData["relationships"]?.objectValue?["sourceBranchOrTag"] == nil)
    }

    @Test func discoveryPreservesScopesAndPagination() throws {
        let workflows = try XcodeCloudService.workflowsRequest(productID: "product-1", pagination: .init(cursor: "page-2", limit: 25))
        #expect(workflows.path == "/v1/ciProducts/product-1/workflows")
        #expect(workflows.parameters?.limit == 25)
        #expect(workflows.parameters?.customs?["cursor"] == "page-2")
        let refs = try XcodeCloudService.gitReferencesRequest(repositoryID: "repository-1", pagination: .init(limit: 10))
        #expect(refs.path == "/v1/scmRepositories/repository-1/gitReferences")
        #expect(refs.parameters?.limit == 10)
    }

    @Test func mapsPendingBuildWithoutInventingCompletionOrDates() throws {
        let data = Data(#"{"type":"ciBuildRuns","id":"run-1","attributes":{"number":42,"executionProgress":"PENDING"},"relationships":{"workflow":{"data":{"type":"ciWorkflows","id":"workflow-1"}}}}"#.utf8)
        let model = try XcodeCloudService.buildRun(JSONDecoder().decode(CiBuildRun.self, from: data))
        #expect(model.buildRunID == "run-1")
        #expect(model.workflowID == "workflow-1")
        #expect(model.number == 42)
        #expect(model.executionProgress == "PENDING")
        #expect(model.completionStatus == nil)
        #expect(model.finishedDate == nil)
    }
}
