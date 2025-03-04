package com.brentvatne.exoplayer.download.infrastructure.remote

import com.brentvatne.exoplayer.download.infrastructure.data.source.RaiDownloadBEDataSource
import com.brentvatne.exoplayer.download.infrastructure.remote.service.RaiDownloadBeService
import okhttp3.ResponseBody
import retrofit2.Call

class RaiDownloadBEDataSourceImpl(private val raiDownloadBeService: RaiDownloadBeService) :
    RaiDownloadBEDataSource {
    override suspend fun getSubtitleFile(url: String): Call<ResponseBody> {
        return raiDownloadBeService.getSubtitleFile(url)
    }
}
