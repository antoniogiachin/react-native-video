package com.brentvatne.exoplayer.download.model.react

import com.brentvatne.exoplayer.download.model.RaiDownloadSubtitle
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableMap
import com.google.gson.annotations.SerializedName

data class ReactDownloadItem(
    @SerializedName("pathId")
    var pathId: String,
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

        pathId.let { map.putString("pathId", it) }
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
        map.putString("pathId", pathId)
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
    var bytesDownloaded: Long?,
    var totalBytes: Long?,
) {
    fun toWritableMap(): ReadableMap? {
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
        }?: map.putNull("mediaInfo")
        map.putString("programPathId", programPathId)
        map.putDouble("bytesDownloaded", (bytesDownloaded?.toDouble() ?: 0) as Double)
        map.putDouble("totalBytes", (totalBytes?.toDouble() ?: 0) as Double)
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
        map.putDouble("bytesDownloaded", (bytesDownloaded?.toDouble() ?: 0) as Double)
        map.putDouble("totalBytes", (totalBytes?.toDouble() ?: 0) as Double)
        return map
    }
}

data class MediaItemDetail(
    val key: String,
    val type: String,
    val value: String
    ) {
    fun toReadableMap(): ReadableMap? {
        val map = Arguments.createMap()
        map.putString("key", key)
        map.putString("type", type)
        map.putString("value", value)
        return map
    }
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

fun ReadableMap.toReactDownloadItem(): ReactDownloadItem {
    val subtitlesList = this.getArray("subtitles")?.let { subtitlesArray ->
        (0 until subtitlesArray.size()).map { index ->
            subtitlesArray.getMap(index)?.let { subtitleMap ->
                RaiDownloadSubtitle(
                    language = subtitleMap.getString("language") ?: "",
                    webUrl = subtitleMap.getString("webUrl") ?: "",  
                    localUrl = subtitleMap.getString("localUrl") ?: ""
                )
            }
        }.filterNotNull()
    }

    val drm: LicenseServer? = this.getMap("drm")?.let { drmMap ->
        LicenseServer(
            type = drmMap.getString("type")?.let { DRMType.fromValue(it) },
            licenseServer = drmMap.getString("licenseServer"),
            licenseToken = drmMap.getString("licenseToken")
        )
    }

    val videoInfo: DownloadVideoInfo? = this.getMap("videoInfo")?.let { videoInfoMap ->
        val mediaInfoList = videoInfoMap.getArray("mediaInfo")?.let { mediaInfoArray ->
            (0 until mediaInfoArray.size()).mapNotNull { index ->
                mediaInfoArray.getMap(index)?.let { mediaInfoMap ->
                    MediaItemDetail(
                        key = mediaInfoMap.getString("key") ?: "",
                        value = mediaInfoMap.getString("value") ?: "",
                        type = mediaInfoMap.getString("icon") ?: "" 
                    )
                }
            }
        }
        DownloadVideoInfo(
            templateImg = videoInfoMap.getString("templateImg") ?: "",
            title = videoInfoMap.getString("title") ?: "",
            description = videoInfoMap.getString("description") ?: "",
            mediaInfo = mediaInfoList,
            programPathId = videoInfoMap.getString("programPathId"),
            bytesDownloaded = if (videoInfoMap.hasKey("bytesDownloaded")) videoInfoMap.getDouble("bytesDownloaded").toLong() else 0L,
            totalBytes = if (videoInfoMap.hasKey("totalBytes")) videoInfoMap.getDouble("totalBytes").toLong() else 0L
        )
    }

    val programInfo: DownloadVideoInfo? = this.getMap("programInfo")?.let { programInfoMap ->
        val mediaInfoList = programInfoMap.getArray("mediaInfo")?.let { mediaInfoArray ->
            (0 until mediaInfoArray.size()).mapNotNull { index ->
                mediaInfoArray.getMap(index)?.let { mediaInfoMap ->
                    MediaItemDetail(
                        key = mediaInfoMap.getString("key") ?: "",
                        value = mediaInfoMap.getString("value") ?: "",
                        type = mediaInfoMap.getString("icon") ?: "" 
                    )
                }
            }
        }

        DownloadVideoInfo(
            templateImg = programInfoMap.getString("templateImg") ?: "",
            title = programInfoMap.getString("title") ?: "",
            description = programInfoMap.getString("description") ?: "",
            mediaInfo = mediaInfoList,
            programPathId = programInfoMap.getString("programPathId"),
            bytesDownloaded = if (programInfoMap.hasKey("bytesDownloaded")) programInfoMap.getDouble("bytesDownloaded").toLong() else 0L,
            totalBytes = if (programInfoMap.hasKey("totalBytes")) programInfoMap.getDouble("totalBytes").toLong() else 0L
        )
    }


    return ReactDownloadItem(
        pathId = this.getString("pathId") ?: "",
        url = this.getString("url") ?: "",
        subtitles = subtitlesList,
        drm = drm,
        videoInfo = videoInfo,
        programInfo = programInfo
    )
}
