package com.brentvatne.exoplayer.download.drm

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.work.WorkerParameters

@UnstableApi
open class DRMLicenseWorker @OptIn(UnstableApi::class) constructor
    (appContext: Context, workerParams: WorkerParameters) :
    AbstractDRMLicenseWorker(appContext, workerParams) {

    override fun notifyResult(contentItemId: String, drmLicenseUrl: String?) {}
}
