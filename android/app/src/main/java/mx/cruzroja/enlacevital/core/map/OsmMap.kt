package mx.cruzroja.enlacevital.core.map

import android.graphics.drawable.GradientDrawable
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.viewinterop.AndroidView
import mx.cruzroja.enlacevital.core.location.Coordinate
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.CustomZoomButtonsController
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker

data class MapMarker(val title: String, val coordinate: Coordinate, val color: Color)

// OpenStreetMap view, so no API key is needed
@Composable
fun OsmMap(center: Coordinate, zoom: Double, markers: List<MapMarker>, modifier: Modifier = Modifier) {
    AndroidView(
        modifier = modifier,
        factory = { context ->
            Configuration.getInstance().userAgentValue = context.packageName
            MapView(context).apply {
                setTileSource(TileSourceFactory.MAPNIK)
                setMultiTouchControls(true)
                zoomController.setVisibility(CustomZoomButtonsController.Visibility.NEVER)
                controller.setZoom(zoom)
                controller.setCenter(GeoPoint(center.latitude, center.longitude))
            }
        },
        update = { map ->
            map.overlays.removeAll { it is Marker }
            markers.forEach { item ->
                map.overlays.add(Marker(map).apply {
                    position = GeoPoint(item.coordinate.latitude, item.coordinate.longitude)
                    title = item.title
                    icon = dot(item.color)
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
                })
            }
            map.invalidate()
        },
    )
}

private fun dot(color: Color) = GradientDrawable().apply {
    shape = GradientDrawable.OVAL
    setColor(color.toArgb())
    setStroke(6, android.graphics.Color.WHITE)
    setSize(48, 48)
}
