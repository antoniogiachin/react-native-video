package com.brentvatne.exoplayer.download.infrastructure.data

import com.brentvatne.exoplayer.download.infrastructure.data.source.RaiDownloadBEDataSource
import okhttp3.ResponseBody
import retrofit2.Call

class RaiDownloadRepository(private val raiDownloadBEDataSource: RaiDownloadBEDataSource) {
    suspend fun getSubTitleFile(url: String): Call<ResponseBody> {
        return raiDownloadBEDataSource.getSubtitleFile(url)
    }
}
