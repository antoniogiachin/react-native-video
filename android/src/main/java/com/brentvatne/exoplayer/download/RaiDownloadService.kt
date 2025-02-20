package com.brentvatne.exoplayer.download

import android.app.Notification
import android.os.Build
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadNotificationHelper
import androidx.media3.exoplayer.offline.DownloadService
import androidx.media3.exoplayer.scheduler.PlatformScheduler
import androidx.media3.exoplayer.scheduler.Requirements
import androidx.media3.exoplayer.scheduler.Scheduler
import com.brentvatne.exoplayer.download.utils.DiUtils
import com.brentvatne.exoplayer.download.utils.DownloadConstants.DOWNLOAD_CHANNEL_ID
import com.brentvatne.exoplayer.download.utils.DownloadConstants.DOWNLOAD_NOTIFICATION_ID
import com.brentvatne.react.R


@OptIn(UnstableApi::class)
class RaiDownloadService : DownloadService(
    DOWNLOAD_NOTIFICATION_ID,
    DEFAULT_FOREGROUND_NOTIFICATION_UPDATE_INTERVAL,
    DOWNLOAD_CHANNEL_ID,
    R.string.exo_download_notification_channel_name,
    0
) {

    override fun getDownloadManager(): DownloadManager {
        val raiDownloadManager: DownloadManager = DiUtils.getDownloadManager(this)
        return raiDownloadManager
    }

    override fun getScheduler(): Scheduler {
        return PlatformScheduler(this, JOB_ID)
    }

    override fun getForegroundNotification(
        downloads: MutableList<Download>,
        notMetRequirements: Int
    ): Notification {
        val downloadNotificationHelper: DownloadNotificationHelper =
            DiUtils.getDownloadNotificationHelper(this)
        val notification = downloadNotificationHelper.buildProgressNotification(
            this,
            R.drawable.ic_download,
            null,
            null,
            downloads,
            Requirements.NETWORK
        )

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            notification.defaults = 0
            notification.sound = null
        }

        return notification
    }

    companion object {
        private const val JOB_ID: Int = 1
    }
}
