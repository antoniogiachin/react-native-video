package com.brentvatne.exoplayer.download.utils

import android.net.Uri
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.exoplayer.offline.Download
import com.brentvatne.exoplayer.download.model.RaiDownloadItem
import com.brentvatne.exoplayer.download.model.RaiDownloadState
import com.brentvatne.exoplayer.download.model.react.DRMType
import com.brentvatne.exoplayer.download.model.react.DownloadVideoInfo
import com.brentvatne.exoplayer.download.model.react.LicenseServer
import com.brentvatne.exoplayer.download.model.react.MediaItemDetail
import com.brentvatne.exoplayer.download.model.react.ReactDownloadItem
import com.facebook.react.bridge.ReadableArray
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
        Download.STATE_STOPPED -> RaiDownloadState.PAUSED
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
        ua = ua,
        contentItemId = null,
        drmLicenseUrl = drm?.licenseServer,
        drmOperator = if(drm != null) "NAGRA" else null,
        nagraToken = drm?.licenseToken,
        downloadableUrl = url,
        isDrm = drm != null,
        downloadSubtitleList = subtitles ?: emptyList(),
        state = RaiDownloadState.valueOf(state ?: RaiDownloadState.QUEUED.name),
        pathId = pathId,
        programPathId = programInfo?.programPathId,
        videoInfo = videoInfo,
        programInfo = programInfo,
        drm = drm,
        mediapolisUrl = null,
        expireDate = expireDate,
        downloadSizeMb = 0,
        bytesDownloaded = videoInfo?.bytesDownloaded ?: 0,
        totalBytes = videoInfo?.totalBytes ?: 0,
        playerSource = playerSource
    )
}

fun RaiDownloadItem.toReactDownloadItem(): ReactDownloadItem {
    return ReactDownloadItem(
        pathId = pathId,
        url = downloadableUrl,
        subtitles = downloadSubtitleList,
        drm = drm,
        videoInfo = videoInfo,
        programInfo = programInfo,
        expireDate = expireDate,
        state = state.name,
        ua = ua,
        playerSource = playerSource
    )
}

fun ReadableMap.toDownloadVideoInfo() : DownloadVideoInfo{
    return DownloadVideoInfo(
        templateImg = getString("templateImg") ?: "",
        title = getString("title") ?: "",
        description = getString("description") ?: "",
        mediaInfo = getArray("mediaInfo")?.toMediaInfo() ?: emptyList(),
        programPathId = getString("programPathId"),
        bytesDownloaded = if (hasKey("bytesDownloaded")) getDouble("bytesDownloaded").toLong() else 0L,
        totalBytes = if (hasKey("totalBytes")) getDouble("totalBytes").toLong() else 0L,
        id = getString("id") ?: ""
    )
}

fun ReadableArray.toMediaInfo() : List<MediaItemDetail>{
    return toArrayList().map {
        it as ReadableMap
        MediaItemDetail(
            key = it.getString("key") ?: "",
            value = it.getString("value") ?: "",
            type = it.getString("icon") ?: "" )
    }
}

fun ReadableMap.toLicenseServer() : LicenseServer {
    return LicenseServer(
        type = DRMType.fromValue(getString("type") ?: ""),
        licenseServer = getString("licenseServer"),
        licenseToken = getString("licenseToken")
    )
}




