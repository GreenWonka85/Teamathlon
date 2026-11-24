package io.github.greenwonka85.teamathlon.android

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import io.github.greenwonka85.teamathlon.android.ui.ServerSelectionScreen
import io.github.greenwonka85.teamathlon.android.ui.theme.TeamathlonTheme
import io.github.greenwonka85.teamathlon.shared.link.AppLink

class MainActivity : ComponentActivity() {
    /** Link aus einem gescannten QR-Code oder geöffneten Einladungslink. */
    private var incomingLink by mutableStateOf<AppLink?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        incomingLink = parseLink(intent)
        setContent {
            TeamathlonTheme {
                // Ein neuer Link setzt den Bildschirm mit der neuen Serveradresse zurück.
                key(incomingLink) {
                    ServerSelectionScreen(
                        initialLink = incomingLink,
                        onServerSelected = { server ->
                            // Platzhalter: Verbindung und Login folgen im nächsten Schritt.
                            Toast.makeText(this@MainActivity, getString(R.string.server_selected, server.url), Toast.LENGTH_LONG).show()
                        },
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        parseLink(intent)?.let { incomingLink = it }
    }

    private fun parseLink(intent: Intent?): AppLink? =
        intent?.dataString?.let(AppLink::parse)
}
