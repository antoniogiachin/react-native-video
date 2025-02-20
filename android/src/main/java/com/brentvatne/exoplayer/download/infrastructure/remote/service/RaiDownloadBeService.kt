package com.brentvatne.exoplayer.download.infrastructure.remote.service

import okhttp3.ResponseBody
import retrofit2.Call
import retrofit2.http.GET
import retrofit2.http.Url

interface RaiDownloadBeService {
    @GET
    fun getSubtitleFile(@Url url: String): Call<ResponseBody>
}
