package com.brentvatne.exoplayer.download.utils

import android.content.Context
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.database.DatabaseProvider
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.Cache
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadNotificationHelper
import com.brentvatne.exoplayer.download.RaiDownloadTracker
import com.brentvatne.exoplayer.download.infrastructure.data.RaiDownloadRepository
import com.brentvatne.exoplayer.download.infrastructure.remote.RaiDownloadBEDataSourceImpl
import com.brentvatne.exoplayer.download.infrastructure.remote.service.RaiDownloadBeService
import com.brentvatne.exoplayer.download.utils.DownloadConstants.APP_NAME
import com.brentvatne.exoplayer.download.utils.DownloadConstants.DOWNLOAD_CHANNEL_ID
import com.brentvatne.exoplayer.download.utils.DownloadConstants.MAX_PARALLEL_DOWNLOADS
import com.brentvatne.exoplayer.download.utils.DownloadConstants.RAI_DOWNLOAD_VIDEO_FOLDER
import com.google.gson.GsonBuilder
import com.jakewharton.retrofit2.adapter.kotlin.coroutines.CoroutineCallAdapterFactory
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@UnstableApi
object DiUtils {
    private var dataSourceFactory: DataSource.Factory? = null
    private var httpDataSourceFactory: DataSource.Factory? = null
    private var databaseProvider: DatabaseProvider? = null
    private var downloadDirectory: File? = null
    private var downloadCache: Cache? = null
    private var downloadManager: DownloadManager? = null
    private var downloadTracker: RaiDownloadTracker? = null
    private var downloadNotificationHelper: DownloadNotificationHelper? = null
    private var retrofit: Retrofit? = null

    @Synchronized
    fun getHttpDataSourceFactory(context: Context): DataSource.Factory {
        if (httpDataSourceFactory == null) {
            httpDataSourceFactory = DefaultHttpDataSource.Factory()
                .setUserAgent(Util.getUserAgent(context, APP_NAME))
                .setAllowCrossProtocolRedirects(true)
        }
        return httpDataSourceFactory as DataSource.Factory
    }

    @Synchronized
    fun getDataSourceFactory(context: Context): DataSource.Factory {
        if (dataSourceFactory == null) {
            val upstreamFactory =
                DefaultDataSource.Factory(context, getHttpDataSourceFactory(context))
            dataSourceFactory =
                buildReadOnlyCacheDataSource(upstreamFactory, getDownloadCache(context))
        }
        return dataSourceFactory as DataSource.Factory
    }

    @Synchronized
    fun getDownloadNotificationHelper(context: Context): DownloadNotificationHelper {
        if (downloadNotificationHelper == null) {
            downloadNotificationHelper = DownloadNotificationHelper(context, DOWNLOAD_CHANNEL_ID)
        }
        return downloadNotificationHelper as DownloadNotificationHelper
    }

    @Synchronized
    fun getDownloadManager(context: Context): DownloadManager {
        ensureDownloadManagerInitialized(context)
        return downloadManager as DownloadManager
    }

    @Synchronized
    fun getDownloadTracker(context: Context): RaiDownloadTracker {
        ensureDownloadManagerInitialized(context)
        return downloadTracker as RaiDownloadTracker
    }

    @Synchronized
    private fun getDownloadCache(context: Context): Cache {
        if (downloadCache == null) {
            val downloadContentDirectory =
                File(getDownloadDirectory(context), RAI_DOWNLOAD_VIDEO_FOLDER)
            downloadCache = SimpleCache(
                downloadContentDirectory, NoOpCacheEvictor(), getDatabaseProvider(context)
            )
        }
        return downloadCache as Cache
    }

    @Synchronized
    private fun ensureDownloadManagerInitialized(context: Context) {
        if (downloadManager == null) {
            downloadManager = DownloadManager(
                context,
                getDatabaseProvider(context),
                getDownloadCache(context),
                getHttpDataSourceFactory(context),
                Executors.newFixedThreadPool(MAX_PARALLEL_DOWNLOADS)
            ).apply {
                maxParallelDownloads = MAX_PARALLEL_DOWNLOADS
                requirements
            }
            downloadTracker = RaiDownloadTracker(
                getHttpDataSourceFactory(context),
                downloadManager!!,
                RaiDownloadRepository(
                    RaiDownloadBEDataSourceImpl(
                        getRetrofit().create(
                            RaiDownloadBeService::class.java
                        )
                    )
                )
            )
        }
    }

    private fun getRetrofit(): Retrofit {
        if (retrofit == null) {
            val builder = OkHttpClient.Builder()
                .connectTimeout(1, TimeUnit.MINUTES)
                .writeTimeout(1, TimeUnit.MINUTES)
                .readTimeout(1, TimeUnit.MINUTES)
                .cache(null)

//            if (BuildConfig.DEBUG) {
//                val httpLoggingInterceptor = HttpLoggingInterceptor { message ->
//                    Log.d("RaiDownload Retrofit", message)
//                }
//
//                //TODO attivare per vedere log sottotitoli
////                httpLoggingInterceptor.apply {
////                    httpLoggingInterceptor.level = HttpLoggingInterceptor.Level.BODY
////                }
//                builder.addNetworkInterceptor(httpLoggingInterceptor)
//            }

            val client = builder.build()

            retrofit = Retrofit.Builder().client(client)
                .baseUrl("https://localhost")
                .addConverterFactory(
                    GsonConverterFactory.create(GsonBuilder().create())
                )
                .addCallAdapterFactory(CoroutineCallAdapterFactory())
                .build()
        }
        return retrofit!!
    }

    @Synchronized
    private fun getDatabaseProvider(context: Context): DatabaseProvider {
        if (databaseProvider == null) {
            databaseProvider = StandaloneDatabaseProvider(context)
        }
        return databaseProvider as DatabaseProvider
    }

    @Synchronized
    fun getDownloadDirectory(context: Context): File {
        if (downloadDirectory == null) {
            downloadDirectory = context.filesDir
        }
        return downloadDirectory as File
    }

    private fun buildReadOnlyCacheDataSource(
        upstreamFactory: DataSource.Factory, cache: Cache
    ): CacheDataSource.Factory {
        return CacheDataSource.Factory()
            .setCache(cache)
            .setUpstreamDataSourceFactory(upstreamFactory)
            .setCacheWriteDataSinkFactory(null)
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
    }

    fun getMimeTypes(url: String): String {
        var mimeTypes = ""
        if (url.contains(".srt")) {
            mimeTypes = MimeTypes.APPLICATION_SUBRIP
        } else if (url.contains(".vtt")) {
            mimeTypes = MimeTypes.TEXT_VTT
        }
        return mimeTypes
    }
}
