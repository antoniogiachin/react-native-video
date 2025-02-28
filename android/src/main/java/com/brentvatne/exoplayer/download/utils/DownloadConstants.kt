package com.brentvatne.exoplayer.download.utils

object DownloadConstants {
    const val APP_NAME = "RaiPlay"
    const val TAG = "DownloadLibrary"
    const val CHECK_DOWNLOADING_TIMER = 1000L
    const val RAI_DOWNLOAD_VIDEO_FOLDER = "RaiPlayDownload_v2"
    const val RAI_DOWNLOAD_IMAGE_FOLDER = "RaiPlayDownloadImage_v2"
    const val RAI_DOWNLOAD_DRM_LICENSE_FOLDER = "RaiPlayDownloadDRMLicense_v2"
    const val RAI_DOWNLOAD_SUBTITLE_FOLDER = "RaiPlayDownloadSubtitle_v2"
    const val DRM_LICENSE_PREFIX = "DRM_LICENSE_"

    //Notification channel
    const val DOWNLOAD_NOTIFICATION_ID = 0xb100
    const val DOWNLOAD_CHANNEL_ID = "it.rainet.raiplay.notification.DOWNLOAD_NOTIFICATION"
    const val DOWNLOAD_NOTIFICATION_CHANNEL_NAME = "Download"
    const val DOWNLOAD_NOTIFICATION_CHANNEL_DESC = "Download"

    //DI
    const val WITH_USER_AGENT = "user_agent"
    const val MAX_PARALLEL_DOWNLOADS = 10
    const val DOWNLOAD_INFO = "DOWNLOAD_INFO"

    //DRM LICENSE WORK PARAMETER
    const val DRM_LICENSE_WORK_NAME = "DRM_LICENSE_WORK"
    const val CONTENT_ITEM_ID = "CONTENT_ITEM_ID"
    const val CONTENT_PATH_ID = "CONTENT_PATH_ID"
    const val PROGRAM_PATH_ID = "PROGRAM_PATH_ID"
    const val USER = "USER"
    const val DOWNLOADABLE_URL = "DOWNLOADABLE_URL"
    const val DRM_LICENSE_URL = "DRM_LICENSE_URL"
    const val DRM_LICENSE_OPERATOR = "DRM_LICENSE_OPERATOR"
    const val DRM_LICENSE_WIDEVINE = "WIDEVINE"
}
