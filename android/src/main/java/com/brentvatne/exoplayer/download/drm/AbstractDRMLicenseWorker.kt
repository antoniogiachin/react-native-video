package com.brentvatne.exoplayer.download.drm

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.exoplayer.dash.DashUtil
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager
import androidx.media3.exoplayer.drm.DrmSessionEventListener
import androidx.media3.exoplayer.drm.OfflineLicenseHelper
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.brentvatne.exoplayer.download.RaiDownloadTracker
import com.brentvatne.exoplayer.download.utils.DiUtils
import com.brentvatne.exoplayer.download.utils.DownloadConstants
import com.brentvatne.exoplayer.download.utils.DownloadConstants.TAG
import com.brentvatne.exoplayer.download.utils.getDrmData

@UnstableApi
abstract class AbstractDRMLicenseWorker(
    private val appContext: Context,
    workerParams: WorkerParameters
) :
    Worker(appContext, workerParams) {

    protected val raiDownloadTracker: RaiDownloadTracker = DiUtils.getDownloadTracker(appContext)

    override fun doWork(): Result {

        try {
            val defaultHttpDataSourceFactory: DataSource.Factory =
                DiUtils.getHttpDataSourceFactory(appContext)

            val contentItemId = inputData.getString(DownloadConstants.CONTENT_ITEM_ID)
            val pathId = inputData.getString(DownloadConstants.CONTENT_PATH_ID) ?: ""
            val programPathId = inputData.getString(DownloadConstants.PROGRAM_PATH_ID) ?: ""
            val user = inputData.getString(DownloadConstants.USER) ?: ""
            val downloadableUrl = inputData.getString(DownloadConstants.DOWNLOADABLE_URL) ?: ""
            val drmLicenseUrl = inputData.getString(DownloadConstants.DRM_LICENSE_URL) ?: ""
            val drmLicenseOperator =
                inputData.getString(DownloadConstants.DRM_LICENSE_OPERATOR) ?: ""

            val id = (contentItemId ?: (user + pathId + programPathId).hashCode().toString())

            if (id.isBlank() || downloadableUrl.isBlank() || drmLicenseUrl.isBlank()) {
                notifyResult(id)
                return Result.failure()
            }
            val drmData =
                getDrmData(drmLicenseUrl, drmLicenseOperator, defaultHttpDataSourceFactory)

            val offlineLicenseHelper = OfflineLicenseHelper(
                DefaultDrmSessionManager.Builder()
                    .build(drmData.callback),
                DrmSessionEventListener.EventDispatcher()
            )


            val dataSource = defaultHttpDataSourceFactory.createDataSource()
            val dashManifest = DashUtil.loadManifest(dataSource, Uri.parse(downloadableUrl))
            val drmInitData =
                DashUtil.loadFormatWithDrmInitData(dataSource, dashManifest.getPeriod(0))

            val offlineLicenseKeySetId: ByteArray =
                drmInitData.let { offlineLicenseHelper.downloadLicense(it!!) }

            raiDownloadTracker.saveDrmLicense(appContext, id, drmLicenseUrl, offlineLicenseKeySetId)

            offlineLicenseHelper.release()

            notifyResult(id, drmLicenseUrl)
            return Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "error download license ${e.message}")
            e.printStackTrace()
            notifyResult("")
            return Result.failure()
        }
    }

    abstract fun notifyResult(contentItemId: String, drmLicenseUrl: String? = null)
}
