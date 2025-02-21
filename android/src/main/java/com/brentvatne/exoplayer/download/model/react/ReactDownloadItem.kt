package com.brentvatne.exoplayer.download.model.react

import com.brentvatne.exoplayer.download.model.RaiDownloadSubtitle
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableMap
import com.google.gson.annotations.SerializedName

data class ReactDownloadItem(
    @SerializedName("mediapolisUrl") //sarà il nuovo ID del download, serve anche per recuperare i DRM aggiornati in caso di errori per setRenewDRM così da aggiornare LicenseServer
    var mediapolisUrl: String,
    @SerializedName("url")
    val url: String,
    @SerializedName("subtitles")
    val subtitles: List<RaiDownloadSubtitle>?,
    @SerializedName("drm")//isDRM
    val drm: LicenseServer?,
    @SerializedName("videoInfo")//puntata
    val videoInfo: DownloadVideoInfo?, 
    @SerializedName("programInfo")//programma
    val programInfo: DownloadVideoInfo?,
) {
    fun toWritableMap(): ReadableMap? {
        val map = Arguments.createMap()

        mediapolisUrl.let { map.putString("mediapolisUrl", it) }
        url.let { map.putString("url", it) }

        subtitles?.let {
            val subtitlesArray = Arguments.createArray()
            it.forEach { subtitle ->
                subtitlesArray.pushMap(subtitle.toWritableMap())
            }
            map.putArray("subtitles", subtitlesArray)
        } ?: map.putNull("subtitles")

        drm?.let { map.putMap("drm", it.toWritableMap()) } ?: map.putNull("drm")
        videoInfo?.let { map.putMap("videoInfo", it.toWritableMap()) } ?: map.putNull("videoInfo")
        programInfo?.let { map.putMap("programInfo", it.toWritableMap()) } ?: map.putNull("programInfo")

        return map
    }

    fun toReadableMap(): ReadableMap? {
        val map = Arguments.createMap()
        map.putString("mediapolisUrl", mediapolisUrl)
        map.putString("url", url)
        subtitles?.let {
            val subtitlesArray = Arguments.createArray()
            it.forEach { subtitle ->
                subtitlesArray.pushMap(subtitle.toReadableMap())
            }
            map.putArray("subtitles", subtitlesArray)
        } ?: map.putNull("subtitles")
        drm?.let { map.putMap("drm", it.toReadableMap()) } ?: map.putNull("drm")
        videoInfo?.let { map.putMap("videoInfo", it.toReadableMap()) } ?: map.putNull("videoInfo")
        programInfo?.let { map.putMap("programInfo", it.toReadableMap()) } ?: map.putNull("programInfo")
        return map
    }
}

data class LicenseServer(
    @SerializedName("type")
    val type: DRMType?,
    @SerializedName("licenseServer")
    val licenseServer: String?,
    @SerializedName("licenseToken")//nagraToken
    val licenseToken: String?
) {
    fun toWritableMap(): ReadableMap? {
        val map = Arguments.createMap()
        type?.let { map.putString("type", it.value) } ?: map.putNull("type")
        licenseServer?.let { map.putString("licenseServer", it) } ?: map.putNull("licenseServer")
        licenseToken?.let { map.putString("licenseToken", it) } ?: map.putNull("licenseToken")
        return map
    }

    fun toReadableMap(): ReadableMap? {
        val map = Arguments.createMap()
        type?.let { map.putString("type", it.value) } ?: map.putNull("type")
        licenseServer?.let { map.putString("licenseServer", it) } ?: map.putNull("licenseServer")
        licenseToken?.let { map.putString("licenseToken", it) } ?: map.putNull("licenseToken")
        return map
    }
}

data class DownloadVideoInfo(
    val templateImg: String, // URL of the video image
    val title: String,
    val description: String,
    val mediaInfo: List<MediaItemDetail>? = null, 
    val programPathId: String?,
    var bytesDownloaded: Long,
    var totalBytes: Long,
) {
    fun toWritableMap(): ReadableMap? {
        val map = Arguments.createMap()
        map.putString("templateImg", templateImg)
        map.putString("title", title)
        map.putString("description", description)

        mediaInfo?.let {
            val programInfoArray = Arguments.createArray()
            it.forEach{mediaItem ->
                programInfoArray.pushMap(mediaItem.toWritableMap())
            }
            map.putArray("mediaInfo", programInfoArray)
        }?: map.putNull("mediaInfo")
        map.putString("programPathId", programPathId)
        map.putDouble("bytesDownloaded", bytesDownloaded.toDouble())
        map.putDouble("totalBytes", totalBytes.toDouble())
        return map
    }

    fun toReadableMap(): ReadableMap? {
        val map = Arguments.createMap()
        map.putString("templateImg", templateImg)
        map.putString("title", title)
        map.putString("description", description)
        mediaInfo?.let {
            val programInfoArray = Arguments.createArray()
            it.forEach{mediaItem ->
                programInfoArray.pushMap(mediaItem.toReadableMap())
            }
            map.putArray("mediaInfo", programInfoArray)
        }
        map.putString("programPathId", programPathId)
        map.putDouble("bytesDownloaded", bytesDownloaded.toDouble())
        map.putDouble("totalBytes", totalBytes.toDouble())
        return map
    }
}

sealed class MediaItemDetail {
    fun toWritableMap(): ReadableMap? {
        val map = Arguments.createMap()
        map.putString("key", key.name)
        map.putString("value", value)

        when (this) {
            is MediaItemDetail.Icon -> map.putString("icon", "icon_value")
            is MediaItemDetail.Label -> {  }
        }
        return map
    }

    fun toReadableMap(): ReadableMap? {
        val map = Arguments.createMap()
        map.putString("key", key.name)
        map.putString("value", value)
        return map
    }

    abstract val key: MediaItemKey
    abstract val value: String

    data class Label(
        override val key: MediaItemKey,
        override val value: String
    ) : MediaItemDetail()

    data class Icon(
        override val key: MediaItemKey,
        override val value: String
    ) : MediaItemDetail()
}

enum class MediaItemKey {
    PROGRAM_NAME,
    AVAILABILITIES,
    SEASONS,
    SUBTITLES,
    RATING
}

enum class DRMType(val value: String) {
    WIDEVINE("widevine"),
    PLAYREADY("playready"),
    CLEARKEY("clearkey"),
    FAIRPLAY("fairplay");

    companion object {
        fun fromValue(value: String): DRMType? = entries.find { it.value == value }
    }
}
