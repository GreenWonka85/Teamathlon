package io.github.greenwonka85.teamathlon.shared.link

/**
 * Inhalte der QR-Codes und Links der App.
 *
 * Es gibt keinen zentralen Dienst, deshalb trägt jeder QR-Code die
 * Serveradresse selbst:
 *
 * - Server wählen: `teamathlon://server?url=https%3A%2F%2Fteamathlon.example.org`
 * - Einladung:     `teamathlon://join?server=https%3A%2F%2Fteamathlon.example.org&code=K7M2QX`
 *
 * Beim Server wählen kann der Nutzer auch nur die Adresse eingeben,
 * siehe [ServerAddress.parse].
 */
sealed interface AppLink {
    val server: ServerAddress

    data class Server(override val server: ServerAddress) : AppLink

    data class Join(override val server: ServerAddress, val code: InviteCode) : AppLink

    fun toUri(): String = when (this) {
        is Server -> "$SCHEME://server?url=${encode(server.url)}"
        is Join -> "$SCHEME://join?server=${encode(server.url)}&code=${code.value}"
    }

    companion object {
        const val SCHEME = "teamathlon"

        /** Liest den Inhalt eines QR-Codes oder Links, oder null, wenn er nicht passt. */
        fun parse(text: String): AppLink? {
            val trimmed = text.trim()
            val prefix = "$SCHEME://"
            if (!trimmed.startsWith(prefix, ignoreCase = true)) return null
            val rest = trimmed.substring(prefix.length)
            val host = rest.substringBefore('?').trimEnd('/').lowercase()
            val params = parseQuery(rest.substringAfter('?', ""))
            return when (host) {
                "server" -> params["url"]?.let(ServerAddress::parse)?.let(::Server)
                "join" -> {
                    val server = params["server"]?.let(ServerAddress::parse) ?: return null
                    val code = params["code"]?.let(InviteCode::parse) ?: return null
                    Join(server, code)
                }
                else -> null
            }
        }

        private fun parseQuery(query: String): Map<String, String> =
            query.split('&')
                .filter { it.contains('=') }
                .associate { decode(it.substringBefore('=')) to decode(it.substringAfter('=')) }

        private const val UNRESERVED = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"

        internal fun encode(value: String): String = buildString {
            for (byte in value.encodeToByteArray()) {
                val c = byte.toInt().toChar()
                if (byte >= 0 && c in UNRESERVED) append(c)
                else append('%').append(((byte.toInt() and 0xFF).toString(16).uppercase().padStart(2, '0')))
            }
        }

        internal fun decode(value: String): String {
            val bytes = ArrayList<Byte>(value.length)
            var i = 0
            while (i < value.length) {
                val c = value[i]
                if (c == '%' && i + 2 < value.length) {
                    val hex = value.substring(i + 1, i + 3).toIntOrNull(16)
                    if (hex != null) {
                        bytes.add(hex.toByte())
                        i += 3
                        continue
                    }
                }
                if (c == '+') bytes.add(' '.code.toByte())
                else c.toString().encodeToByteArray().forEach(bytes::add)
                i++
            }
            return bytes.toByteArray().decodeToString()
        }
    }
}

/** Einladungscode aus 6 bis 12 Zeichen (Großbuchstaben und Ziffern). */
@ConsistentCopyVisibility
data class InviteCode private constructor(val value: String) {
    companion object {
        private val PATTERN = Regex("^[A-Z0-9]{6,12}$")

        fun parse(text: String): InviteCode? {
            val normalized = text.trim().uppercase()
            return if (PATTERN.matches(normalized)) InviteCode(normalized) else null
        }
    }
}

/**
 * Adresse eines Teamathlon-Servers, normalisiert ohne abschließenden Schrägstrich.
 *
 * Unverschlüsseltes `http` ist nur für Adressen im lokalen Netz erlaubt
 * (z.B. ein Raspberry Pi zu Hause während der Entwicklung). Fehlt das
 * Schema, wird `https` angenommen.
 */
@ConsistentCopyVisibility
data class ServerAddress private constructor(val url: String) {
    val host: String
        get() = url.substringAfter("://").substringBefore('/').substringBefore(':').removePrefix("[").removeSuffix("]")

    companion object {
        private val HOST_PATTERN = Regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?)(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$")

        fun parse(text: String): ServerAddress? {
            var input = text.trim()
            if (input.isEmpty() || input.any { it.isWhitespace() }) return null
            if (!input.contains("://")) input = "https://$input"
            val scheme = input.substringBefore("://").lowercase()
            if (scheme != "https" && scheme != "http") return null
            val afterScheme = input.substringAfter("://")
            val authority = afterScheme.substringBefore('/').substringBefore('?').substringBefore('#')
            if (authority.contains('@')) return null
            val path = afterScheme.removePrefix(authority).substringBefore('?').substringBefore('#').trimEnd('/')
            val host = authority.substringBefore(':').lowercase()
            val port = authority.substringAfter(':', "")
            if (!HOST_PATTERN.matches(host)) return null
            if (port.isNotEmpty() && (port.toIntOrNull() ?: 0) !in 1..65535) return null
            if (scheme == "http" && !isLocal(host)) return null
            val normalizedAuthority = if (port.isEmpty()) host else "$host:$port"
            return ServerAddress("$scheme://$normalizedAuthority$path")
        }

        /** Hostnamen und IPv4-Adressen, die nur im lokalen Netz erreichbar sind. */
        internal fun isLocal(host: String): Boolean {
            if (host == "localhost" || host.endsWith(".local") || host.endsWith(".lan") || host.endsWith(".home.arpa")) return true
            val parts = host.split('.').map { it.toIntOrNull() ?: return false }
            if (parts.size != 4 || parts.any { it !in 0..255 }) return false
            return when {
                parts[0] == 10 -> true
                parts[0] == 127 -> true
                parts[0] == 192 && parts[1] == 168 -> true
                parts[0] == 172 && parts[1] in 16..31 -> true
                else -> false
            }
        }
    }
}
