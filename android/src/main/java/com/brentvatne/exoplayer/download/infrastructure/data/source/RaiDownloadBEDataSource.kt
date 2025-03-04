package com.brentvatne.exoplayer.download.infrastructure.data.source

import okhttp3.ResponseBody
import retrofit2.Call

interface RaiDownloadBEDataSource {
    suspend fun getSubtitleFile(url: String): Call<ResponseBody>
}
