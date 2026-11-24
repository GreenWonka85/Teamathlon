package io.github.greenwonka85.teamathlon.shared

import io.github.greenwonka85.teamathlon.shared.link.AppLink
import io.github.greenwonka85.teamathlon.shared.link.InviteCode
import io.github.greenwonka85.teamathlon.shared.link.ServerAddress
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull

class AppLinkTest {
    @Test
    fun plainHostBecomesHttps() {
        assertEquals("https://teamathlon.uni-example.de", ServerAddress.parse(" Teamathlon.Uni-Example.de/ ")?.url)
    }

    @Test
    fun httpOnlyAllowedInLocalNetwork() {
        assertEquals("http://192.168.178.40:8000", ServerAddress.parse("http://192.168.178.40:8000")?.url)
        assertEquals("http://teamathlon-pi.local:8000", ServerAddress.parse("http://teamathlon-pi.local:8000")?.url)
        assertNull(ServerAddress.parse("http://teamathlon.example.org"))
        assertNull(ServerAddress.parse("http://8.8.8.8"))
    }

    @Test
    fun invalidAddressesAreRejected() {
        assertNull(ServerAddress.parse(""))
        assertNull(ServerAddress.parse("ftp://example.org"))
        assertNull(ServerAddress.parse("https://user@example.org"))
        assertNull(ServerAddress.parse("https://exa mple.org"))
        assertNull(ServerAddress.parse("https://example.org:99999"))
    }

    @Test
    fun joinLinkRoundTrip() {
        val link = AppLink.Join(ServerAddress.parse("https://teamathlon.example.org")!!, InviteCode.parse("k7m2qx")!!)
        val uri = link.toUri()
        assertEquals("teamathlon://join?server=https%3A%2F%2Fteamathlon.example.org&code=K7M2QX", uri)
        assertEquals(link, AppLink.parse(uri))
    }

    @Test
    fun serverLinkRoundTrip() {
        val link = AppLink.Server(ServerAddress.parse("http://192.168.178.40:8000")!!)
        val parsed = AppLink.parse(link.toUri())
        assertIs<AppLink.Server>(parsed)
        assertEquals("http://192.168.178.40:8000", parsed.server.url)
    }

    @Test
    fun foreignOrBrokenQrCodesAreIgnored() {
        assertNull(AppLink.parse("https://example.org"))
        assertNull(AppLink.parse("teamathlon://join?server=https%3A%2F%2Fexample.org"))
        assertNull(AppLink.parse("teamathlon://join?server=https%3A%2F%2Fexample.org&code=ab"))
        assertNull(AppLink.parse("teamathlon://unbekannt?url=x"))
        assertNotNull(AppLink.parse("TEAMATHLON://server?url=example.org"))
    }
}
