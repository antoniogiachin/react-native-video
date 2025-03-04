package com.brentvatne.exoplayer.download.model

import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.drm.HttpMediaDrmCallback

data class DrmData @OptIn(UnstableApi::class) constructor
    (
    val drmLicenseUrl: String,
    val callback: HttpMediaDrmCallback,
    val optionalParams: HashMap<String, String>
)
