import Foundation

protocol FamilyServicing: Sendable {
    func fetchMembers() async throws -> [FamilyMember]
    func fetchActiveAlert() async throws -> FamilyAlert?
    func sendWellbeingCheck(to memberName: String) async throws
}

struct MockFamilyService: FamilyServicing {
    func fetchMembers() async throws -> [FamilyMember] {
        FamilyMember.samples
    }

    func fetchActiveAlert() async throws -> FamilyAlert? {
        .sample
    }

    func sendWellbeingCheck(to memberName: String) async throws {}
}
