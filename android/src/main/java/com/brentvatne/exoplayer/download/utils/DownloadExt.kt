package com.brentvatne.exoplayer.download.utils

import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.exoplayer.offline.Download
import com.brentvatne.exoplayer.download.model.RaiDownloadItem
import com.brentvatne.exoplayer.download.model.RaiDownloadState
import com.brentvatne.exoplayer.download.model.react.ReactDownloadItem
import com.facebook.react.bridge.ReadableMap
import com.google.gson.Gson


@OptIn(UnstableApi::class)
fun ByteArray.toRaiDownloadItem(): RaiDownloadItem? {
    return try {
        val raiDownloadItem = Gson().fromJson(Util.fromUtf8Bytes(this), RaiDownloadItem::class.java)
        raiDownloadItem
    } catch (ex: Exception) {
        null
    }
}

@OptIn(UnstableApi::class)
fun Download.toRaiDownloadState(): RaiDownloadState {
    return when (this.state) {
        Download.STATE_QUEUED -> RaiDownloadState.QUEUED
        Download.STATE_DOWNLOADING -> RaiDownloadState.DOWNLOADING
        Download.STATE_STOPPED -> RaiDownloadState.STOPPED
        Download.STATE_RESTARTING -> RaiDownloadState.RESTARTING
        Download.STATE_COMPLETED -> RaiDownloadState.COMPLETED
        Download.STATE_FAILED -> RaiDownloadState.FAILED
        Download.STATE_REMOVING -> RaiDownloadState.REMOVING
        else -> RaiDownloadState.QUEUED
    }
}

fun String.getDrmLicenseQueryParams(): HashMap<String, String> {
    val optionalKeyRequestParameters = HashMap<String, String>()

    if (this.isNotBlank()) {
        val drmLicenseUri = Uri.parse(this)

        drmLicenseUri.queryParameterNames.forEach { key ->
            drmLicenseUri.getQueryParameter(key)?.let {
                optionalKeyRequestParameters[key] = it
            }
        }
    }

    return optionalKeyRequestParameters
}

fun ReactDownloadItem.toRaiDownloadItem(): RaiDownloadItem {
    return RaiDownloadItem(
        ua = null,
        contentItemId = null,
        drmLicenseUrl = drm?.licenseServer,
        drmOperator = if(drm != null) "NAGRA" else null,
        nagraToken = drm?.licenseToken,
        downloadableUrl = url,
        isDrm = drm != null,
        downloadSubtitleList = subtitles ?: emptyList(),
        state = RaiDownloadState.QUEUED,
        pathId = null,
        programPathId = null,
        videoInfo = videoInfo,
        programInfo = programInfo,
        drm = drm,
        mediapolisUrl = mediapolisUrl
    )
}

fun RaiDownloadItem.toReactDownloadItem(): ReactDownloadItem {
    return ReactDownloadItem(
        mediapolisUrl = mediapolisUrl ?: "",
        url = downloadableUrl,
        subtitles = downloadSubtitleList,
        drm = drm,
        videoInfo = videoInfo,
        programInfo = programInfo
    )
}

fun ReadableMap.toReactDownloadItem(): ReactDownloadItem{
    return ReactDownloadItem(
        mediapolisUrl = getString("mediapolisUrl") ?: "",
        url = getString("url") ?: "",
        subtitles = null,
        drm = null,
        videoInfo = null,
        programInfo = null
    )
}
