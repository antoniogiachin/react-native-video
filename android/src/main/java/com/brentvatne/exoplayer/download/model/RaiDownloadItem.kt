package com.brentvatne.exoplayer.download.model

import com.brentvatne.exoplayer.download.model.react.DownloadVideoInfo
import com.brentvatne.exoplayer.download.model.react.LicenseServer
import com.brentvatne.exoplayer.download.utils.toDownloadVideoInfo
import com.brentvatne.exoplayer.download.utils.toLicenseServer
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.google.gson.annotations.SerializedName

data class RaiDownloadItem(
    @SerializedName("user")
    val ua: String?,
    @SerializedName("contentItemId")
    val contentItemId: String?,
    @SerializedName("drmLicenseUrl")
    var drmLicenseUrl: String?,
    @SerializedName("drmOperator")
    var drmOperator: String?,
    @SerializedName("nagraToken")
    var nagraToken: String?,
    @SerializedName("downloadableUrl")
    var downloadableUrl: String,
    @SerializedName("isDrm")
    val isDrm: Boolean,
    @SerializedName("downloadSubtitleList")
    var downloadSubtitleList: List<RaiDownloadSubtitle>,
    @SerializedName("state")
    var state: RaiDownloadState = RaiDownloadState.QUEUED,
    @SerializedName("downloadSizeMb")
    var downloadSizeMb: Long = 0L,
    @SerializedName("bytesDownloaded")
    var bytesDownloaded: Long = 0L,
    @SerializedName("totalBytes")
    var totalBytes: Long = 0L,
    @SerializedName("pathId")
    val pathId: String,
    @SerializedName("programPathId")
    val programPathId: String?,
    @SerializedName("videoInfo")
    val videoInfo: DownloadVideoInfo? = null,
    @SerializedName("programInfo")
    val programInfo: DownloadVideoInfo? = null,
    @SerializedName("drm")
    val drm: LicenseServer? = null,
    @SerializedName("mediapolisUrl")
    val mediapolisUrl: String? = null,
    @SerializedName("expireDate")
    val expireDate: String? = null,
    @SerializedName("playerSource")
    var playerSource: String?,
)

fun ReadableMap.toRaiDownloadItem(): RaiDownloadItem {
    val subtitles = mutableListOf<RaiDownloadSubtitle>()
    val externalSubtitles = getArray("externalSubtitles")
    for (i in 0 until (externalSubtitles?.size() ?: -1)) {
        val element = externalSubtitles!!.getMap(i)
        subtitles.add(
            RaiDownloadSubtitle(
                language = element.getString("label") ?: "",
                webUrl = element.getString("url") ?: "",
                localUrl = ""
            )
        )
    }
    return RaiDownloadItem(
        ua = getString("ua"),
        contentItemId = null,
        drmLicenseUrl = getMap("drm")?.getString("licenceUrl"),
        drmOperator = getMap("drm")?.getString("operator"),
        nagraToken = getMap("drm")?.getString("nagraAuthToken"),
        downloadableUrl = getString("url") ?: "",
        isDrm = getMap("drm") != null,
        downloadSubtitleList = subtitles,
        state = RaiDownloadState.QUEUED,
        pathId = getString("pathId") ?: "",
        programPathId = getString("programPathId"),
        expireDate = getString("expireDate"),
        videoInfo = getMap("videoInfo")?.toDownloadVideoInfo(),
        programInfo = getMap("programInfo")?.toDownloadVideoInfo(),
        drm = getMap("drm")?.toLicenseServer(),
        mediapolisUrl = getString("mediapolisUrl"),
        playerSource = getString("playerSource")
    )
}

fun RaiDownloadItem.toReadableMap(): WritableMap {
    val ret = Arguments.createMap()

    ret.putString("ua", ua)
    ret.putString("pathId", pathId)
    ret.putString("programPathId", programPathId)
    ret.putInt("sizeInMb", this.downloadSizeMb.toInt())
    ret.putString("status", state.convertToReactEnum())

    val progress = Arguments.createMap()
    progress.putDouble(
        "total",
        if (state == RaiDownloadState.COMPLETED) bytesDownloaded.toDouble() else totalBytes.toDouble()
    )
    progress.putDouble("downloaded", bytesDownloaded.toDouble())
    ret.putMap("progress", progress)

    ret.putBoolean("isDrm", isDrm)
    ret.putString("url", downloadableUrl)
    ret.putString("expireDate", expireDate)
    ret.putString("mediapolisUrl", mediapolisUrl)
    ret.putString("playerSource", playerSource)

    return ret
}

fun RaiDownloadState.convertToReactEnum(): String =
    when (this) {
        RaiDownloadState.LICENSE_DOWNLOADED -> "LicenseDownloaded"
        RaiDownloadState.QUEUED -> "Queue"
        RaiDownloadState.DOWNLOADING -> "Downloading"
        RaiDownloadState.STOPPED -> "Paused"
        RaiDownloadState.RESTARTING -> "Downloading"
        RaiDownloadState.COMPLETED -> "Completed"
        RaiDownloadState.FAILED -> "Completed"
        RaiDownloadState.REMOVING -> "Removing"
        RaiDownloadState.REMOVED -> "Completed"
    }
