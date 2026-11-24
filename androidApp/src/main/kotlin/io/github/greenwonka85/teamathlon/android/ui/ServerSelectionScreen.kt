package io.github.greenwonka85.teamathlon.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.github.greenwonka85.teamathlon.android.R
import io.github.greenwonka85.teamathlon.android.ui.theme.TeamathlonColors
import io.github.greenwonka85.teamathlon.android.ui.theme.TeamathlonTheme
import io.github.greenwonka85.teamathlon.shared.link.AppLink
import io.github.greenwonka85.teamathlon.shared.link.ServerAddress

/**
 * Erster Bildschirm: Server per QR-Code oder Adresse wählen.
 * Die Verbindung zum Server und der Login folgen im nächsten Schritt.
 */
@Composable
fun ServerSelectionScreen(
    initialLink: AppLink?,
    onServerSelected: (ServerAddress) -> Unit,
    modifier: Modifier = Modifier,
) {
    var address by rememberSaveable { mutableStateOf(initialLink?.server?.url.orEmpty()) }
    var showError by rememberSaveable { mutableStateOf(false) }
    var info by rememberSaveable { mutableStateOf<String?>(null) }
    val scanComingText = stringResource(R.string.scan_qr_coming)
    val inviteText = (initialLink as? AppLink.Join)?.let { stringResource(R.string.invite_detected, it.code.value) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .safeDrawingPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 32.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        SportStripes()
        Text(stringResource(R.string.welcome_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.welcome_intro), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
        Text(stringResource(R.string.welcome_server_hint), style = MaterialTheme.typography.bodyMedium)

        Button(
            onClick = { info = scanComingText },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
        ) {
            Column(Modifier.padding(vertical = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(stringResource(R.string.scan_qr), style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(4.dp))
                Text(stringResource(R.string.scan_qr_hint), style = MaterialTheme.typography.bodySmall)
            }
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            HorizontalDivider(Modifier.weight(1f))
            Text(stringResource(R.string.or_enter_address), Modifier.padding(horizontal = 8.dp), style = MaterialTheme.typography.bodySmall)
            HorizontalDivider(Modifier.weight(1f))
        }

        OutlinedTextField(
            value = address,
            onValueChange = { address = it; showError = false },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.server_address)) },
            placeholder = { Text(stringResource(R.string.server_address_placeholder)) },
            singleLine = true,
            isError = showError,
            supportingText = if (showError) {
                { Text(stringResource(R.string.server_address_invalid)) }
            } else null,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = ImeAction.Go),
        )

        OutlinedButton(
            onClick = {
                val parsed = ServerAddress.parse(address)
                if (parsed == null) showError = true else onServerSelected(parsed)
            },
            modifier = Modifier.fillMaxWidth(),
        ) { Text(stringResource(R.string.connect)) }

        (info ?: inviteText)?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary) }

        Surface(color = MaterialTheme.colorScheme.surfaceVariant, shape = RoundedCornerShape(12.dp)) {
            Text(stringResource(R.string.privacy_note), Modifier.padding(16.dp), style = MaterialTheme.typography.bodySmall)
        }
    }
}

/** Die drei Farbstreifen für Schwimmen, Rad und Lauf. */
@Composable
private fun SportStripes() {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        listOf(TeamathlonColors.Swim, TeamathlonColors.Bike, TeamathlonColors.Run).forEach { color: Color ->
            Box(Modifier.width(32.dp).height(6.dp).background(color, RoundedCornerShape(3.dp)))
        }
    }
}

@Preview(showBackground = true, widthDp = 390, heightDp = 844)
@Composable
private fun ServerSelectionPreview() {
    TeamathlonTheme { ServerSelectionScreen(initialLink = null, onServerSelected = {}) }
}
