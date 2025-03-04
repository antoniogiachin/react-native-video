package com.brentvatne.exoplayer.download.utils

import android.net.Uri
import android.text.TextUtils
import android.util.Log
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.exoplayer.drm.HttpMediaDrmCallback
import com.brentvatne.exoplayer.download.model.DrmData
import com.brentvatne.exoplayer.download.utils.DownloadConstants.TAG

const val NAGRA = "nagra"


fun Uri.getUriWithoutQueryParam(tag: String): Uri {
    val uri = this.buildUpon().clearQuery()
    this.queryParameterNames.filterNot { it == tag }.forEach { qp ->
        uri.appendQueryParameter(qp, this.getQueryParameter(qp))
    }

    return uri.build()
}

fun getDrmLicenseQueryParams(drmLicenseUrl: String?): HashMap<String, String> {

    val optionalKeyRequestParameters = HashMap<String, String>()

    if (!TextUtils.isEmpty(drmLicenseUrl)) {

        val drmLicenseUri = Uri.parse(drmLicenseUrl)

        if (drmLicenseUri.queryParameterNames.isNotEmpty()) {
            for (key in drmLicenseUri.queryParameterNames) {
                drmLicenseUri.getQueryParameter(key)?.let {
                    optionalKeyRequestParameters[key] = it
                }
            }
        }
    }

    return optionalKeyRequestParameters
}

@OptIn(UnstableApi::class)
fun getDrmData(
    drmLicenseUrl: String?,
    operator: String?,
    licenseDataSourceFactory: DataSource.Factory
): DrmData {
    return when (operator) {
        NAGRA -> {
            val uri = Uri.parse(drmLicenseUrl)
            val auth = uri.getQueryParameter("Authorization") ?: ""
            val newDrmLicenseUrl = uri.getUriWithoutQueryParam("Authorization").toString()
            val callback =
                HttpMediaDrmCallback(newDrmLicenseUrl, true, licenseDataSourceFactory).apply {
                    setKeyRequestProperty(
                        "nv-authorizations",
                        auth
                    )
                }
            Log.d(TAG, "download $drmLicenseUrl with operator $operator and token $auth")

            DrmData(newDrmLicenseUrl, callback, getDrmLicenseQueryParams(newDrmLicenseUrl))
        }

        else -> {
            DrmData(
                drmLicenseUrl ?: "",
                HttpMediaDrmCallback(drmLicenseUrl, true, licenseDataSourceFactory),
                getDrmLicenseQueryParams(drmLicenseUrl)
            )
        }
    }

}
