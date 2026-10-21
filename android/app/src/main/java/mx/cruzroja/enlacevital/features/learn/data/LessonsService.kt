package mx.cruzroja.enlacevital.features.learn.data

import mx.cruzroja.enlacevital.features.learn.model.Lesson
import mx.cruzroja.enlacevital.features.learn.model.sampleLessons

interface LessonsService {
    suspend fun fetchLessons(): List<Lesson>
}

class MockLessonsService : LessonsService {
    override suspend fun fetchLessons() = sampleLessons
}
