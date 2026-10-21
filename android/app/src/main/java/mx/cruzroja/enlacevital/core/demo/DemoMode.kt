package mx.cruzroja.enlacevital.core.demo

// Screenshot mode: adb shell am start ... -e demo report
object DemoMode {
    var current: String = ""

    fun isActive(vararg names: String) = current in names
}
