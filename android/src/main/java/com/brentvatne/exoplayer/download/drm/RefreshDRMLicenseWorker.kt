package com.brentvatne.exoplayer.download.drm

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.work.WorkerParameters

@UnstableApi
class RefreshDRMLicenseWorker @OptIn(UnstableApi::class) constructor
    (private val appContext: Context, workerParams: WorkerParameters) :
    AbstractDRMLicenseWorker(appContext, workerParams) {

    override fun notifyResult(contentItemId: String, drmLicenseUrl: String?) {
        raiDownloadTracker.emitRenewLicense(contentItemId, contentItemId.isNotBlank())
    }
}
