package mx.cruzroja.enlacevital.core.location

data class Coordinate(val latitude: Double, val longitude: Double) {
    companion object {
        val MONTERREY = Coordinate(25.6516, -100.2895)
    }
}
