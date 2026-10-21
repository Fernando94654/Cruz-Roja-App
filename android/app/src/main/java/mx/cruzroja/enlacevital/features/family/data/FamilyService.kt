package mx.cruzroja.enlacevital.features.family.data

import mx.cruzroja.enlacevital.features.family.model.FamilyAlert
import mx.cruzroja.enlacevital.features.family.model.FamilyMember
import mx.cruzroja.enlacevital.features.family.model.sampleFamilyMembers

interface FamilyService {
    suspend fun fetchMembers(): List<FamilyMember>
    suspend fun fetchActiveAlert(): FamilyAlert?
    suspend fun sendWellbeingCheck(memberName: String)
}

class MockFamilyService : FamilyService {
    override suspend fun fetchMembers() = sampleFamilyMembers
    override suspend fun fetchActiveAlert() = FamilyAlert.SAMPLE
    override suspend fun sendWellbeingCheck(memberName: String) {}
}
