package com.brentvatne.exoplayer.download

import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.util.UnstableApi
import androidx.media3.common.util.Util
import androidx.media3.datasource.DataSource
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager
import androidx.media3.exoplayer.drm.FrameworkMediaDrm
import androidx.media3.exoplayer.drm.HttpMediaDrmCallback
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadHelper
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadService
import androidx.media3.ui.DefaultTrackNameProvider
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.brentvatne.exoplayer.download.drm.DRMLicenseWorker
import com.brentvatne.exoplayer.download.drm.RefreshDRMLicenseWorker
import com.brentvatne.exoplayer.download.infrastructure.data.RaiDownloadRepository
import com.brentvatne.exoplayer.download.model.ErrorItem
import com.brentvatne.exoplayer.download.model.ExoPlayerTrack
import com.brentvatne.exoplayer.download.model.RaiDownloadItem
import com.brentvatne.exoplayer.download.model.RaiDownloadState
import com.brentvatne.exoplayer.download.model.RaiDownloadSubtitle
import com.brentvatne.exoplayer.download.model.RenewLicenseResult
import com.brentvatne.exoplayer.download.model.Track
import com.brentvatne.exoplayer.download.utils.DownloadConstants.CHECK_DOWNLOADING_TIMER
import com.brentvatne.exoplayer.download.utils.DownloadConstants.CONTENT_ITEM_ID
import com.brentvatne.exoplayer.download.utils.DownloadConstants.CONTENT_PATH_ID
import com.brentvatne.exoplayer.download.utils.DownloadConstants.DOWNLOADABLE_URL
import com.brentvatne.exoplayer.download.utils.DownloadConstants.DRM_LICENSE_OPERATOR
import com.brentvatne.exoplayer.download.utils.DownloadConstants.DRM_LICENSE_PREFIX
import com.brentvatne.exoplayer.download.utils.DownloadConstants.DRM_LICENSE_URL
import com.brentvatne.exoplayer.download.utils.DownloadConstants.DRM_LICENSE_WIDEVINE
import com.brentvatne.exoplayer.download.utils.DownloadConstants.DRM_LICENSE_WORK_NAME
import com.brentvatne.exoplayer.download.utils.DownloadConstants.PROGRAM_PATH_ID
import com.brentvatne.exoplayer.download.utils.DownloadConstants.RAI_DOWNLOAD_DRM_LICENSE_FOLDER
import com.brentvatne.exoplayer.download.utils.DownloadConstants.RAI_DOWNLOAD_SUBTITLE_FOLDER
import com.brentvatne.exoplayer.download.utils.DownloadConstants.TAG
import com.brentvatne.exoplayer.download.utils.DownloadConstants.USER
import com.brentvatne.exoplayer.download.utils.NAGRA
import com.brentvatne.exoplayer.download.utils.getDrmLicenseQueryParams
import com.brentvatne.exoplayer.download.utils.toRaiDownloadItem
import com.brentvatne.exoplayer.download.utils.toRaiDownloadState
import com.brentvatne.react.DownloadManagerModule.Companion.DOWNLOAD_QUALITY_REQUESTED
import com.google.gson.Gson
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import okhttp3.ResponseBody
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Response
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.io.OutputStreamWriter

@UnstableApi
class RaiDownloadTracker @OptIn(UnstableApi::class) constructor
    (
    private val defaultHttpDataSourceFactory: DataSource.Factory,
    private val downloadManager: DownloadManager,
    private val raiDownloadRepository: RaiDownloadRepository,
)
{
    private val downloadListFlow = MutableSharedFlow<List<RaiDownloadItem>>()
    private val downloadProgressListFlow = MutableSharedFlow<List<RaiDownloadItem>>()
    private val errorDownloadFlow = MutableSharedFlow<ErrorItem>()
    private val renewLicenseFlow = MutableSharedFlow<RenewLicenseResult>()
    private val downloadMap = hashMapOf<String, RaiDownloadItem>()
    private val downloadHandler = Handler(Looper.getMainLooper())
    private var runnableStarted = false

    private val downloadRunnable: Runnable = Runnable {
        downloadMap.filter { it.value.state == RaiDownloadState.DOWNLOADING }
            .forEach { raiDownloadItem ->
                try {
                    val download = downloadManager.downloadIndex.getDownload(raiDownloadItem.key)
                    download?.let {
                        raiDownloadItem.value.downloadSizeMb =
                            download.bytesDownloaded / (1024 * 1024)
                        raiDownloadItem.value.bytesDownloaded = download.bytesDownloaded
                        if (download.percentDownloaded.toLong() != 0L)
                            raiDownloadItem.value.totalBytes = (download.bytesDownloaded * 100) / download.percentDownloaded.toLong()
                    }
                } catch (e: Exception) {
                    Log.e(
                        TAG,
                        "Error: failed to update download progress for download ${raiDownloadItem.key}", e
                    )
                }
            }

        //postDownloadList()
        postDownloadProgressList()
        startDownloadRunnable()
    }

    private fun startDownloadRunnable() {
        if (!runnableStarted) {
            runnableStarted = true
            destroyDownloadRunnable()
            downloadHandler.postDelayed(downloadRunnable, CHECK_DOWNLOADING_TIMER)
        }
    }

    private fun destroyDownloadRunnable() {
        runnableStarted = false
        downloadHandler.removeCallbacks(downloadRunnable)
    }

    fun retrieveDownloads(context: Context) {
        downloadManager.addListener(DownloadManagerListener(context))
        startRaiDownloadService(context)
        loadDownload() {
            postDownloadList()
        }
    }

    private fun loadDownload(finallyFunc: (() -> Unit)? = null) {
        try {
            val loadedDownloads = downloadManager.downloadIndex.getDownloads()
            while (loadedDownloads.moveToNext()) {
                val download = loadedDownloads.download
                val raiDownloadItem = download.request.data.toRaiDownloadItem()
                Log.d(TAG, "loadDownload $raiDownloadItem")
                Log.d(TAG, "loadDownload ${download.request.data}")
                raiDownloadItem?.run {
                    state = download.toRaiDownloadState()
                    downloadSizeMb = download.bytesDownloaded / (1024 * 1024)
                    bytesDownloaded = download.bytesDownloaded
                    totalBytes = download.contentLength
                    downloadMap[getId(raiDownloadItem, true)] = raiDownloadItem
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error: failed to load downloads")
        } finally {
            finallyFunc?.invoke()
        }
    }

    private fun postDownloadList() {
        CoroutineScope(Dispatchers.Default).launch {
            downloadListFlow.emit(downloadMap.values.toList().filter { it.state != RaiDownloadState.FAILED })
        }
        Log.d(TAG, "postDownloadList ${downloadMap.values.toList().filter { it.state != RaiDownloadState.FAILED }}")
    }

    private fun postDownloadProgressList() {
        CoroutineScope(Dispatchers.Default).launch {
            downloadProgressListFlow.emit(downloadMap.values.toList().filter { it.state == RaiDownloadState.DOWNLOADING })
        }
        Log.d(TAG, "postDownloadProgressList ${downloadMap.values.toList().filter { it.state == RaiDownloadState.DOWNLOADING }}")
    }

    fun getDownloadMap() : HashMap<String, RaiDownloadItem> {
        return downloadMap
    }

    private fun startRaiDownloadService(activityContext: Context) {
        try {
            // Per Android 12 (API 31) e versioni successive, i servizi in primo piano devono essere avviati immediatamente.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                DownloadService.startForeground(activityContext, RaiDownloadService::class.java)
            } else {
                // Per Android 11 (API 30) e successivi, è possibile avviare il servizio normalmente
                DownloadService.start(activityContext, RaiDownloadService::class.java)
            }
        } catch (e: Exception) {
            Log.e("RaiDownloadTracker", "Failed to start download service -> ${Log.getStackTraceString(e)}")
        }
    }

    fun subscribeDownloads(
        task: (List<RaiDownloadItem>) -> Unit
    ) {
        downloadListFlow.asSharedFlow().onEach { task(it) }.launchIn(CoroutineScope(Dispatchers.Default))
    }

    fun subscribeError(task: (ErrorItem) -> Unit) {
        errorDownloadFlow.asSharedFlow().onEach { task(it) }.launchIn(CoroutineScope(Dispatchers.Default))
    }

    fun subscribeRenewLicense(task: (RenewLicenseResult) -> Unit) {
        renewLicenseFlow.asSharedFlow().onEach { task(it) }.launchIn(CoroutineScope(Dispatchers.Default))
    }

    fun emitRenewLicense(id: String, result: Boolean) {
        CoroutineScope(Dispatchers.Default).launch {
            downloadMap[id]?.let {
                renewLicenseFlow.emit(RenewLicenseResult(it, result))
            }
        }
    }

    fun subscribeProgress(
        task: (List<RaiDownloadItem>) -> Unit
    ) {
        downloadProgressListFlow.asSharedFlow().onEach { task(it) }.launchIn(CoroutineScope(Dispatchers.Default))
    }

    private fun getDownloadHelper(context: Context, mediaItem: MediaItem, drmLicenseUrl: String, operator: String): DownloadHelper {

        val drmKeyRequestProperties = drmLicenseUrl.getDrmLicenseQueryParams()

        val httpMediaDrmCallback =
            HttpMediaDrmCallback(drmLicenseUrl, defaultHttpDataSourceFactory)

        drmKeyRequestProperties.keys.forEach { key ->
            httpMediaDrmCallback.setKeyRequestProperty(key, drmKeyRequestProperties[key].toString())
        }

        if (operator == NAGRA) {
            val uri = Uri.parse(drmLicenseUrl)
            val auth = uri.getQueryParameter("Authorization") ?: ""
            httpMediaDrmCallback.setKeyRequestProperty("nv-authorizations", auth)
        }

        val drmSessionManager = DefaultDrmSessionManager.Builder()
            .setUuidAndExoMediaDrmProvider(
                C.WIDEVINE_UUID,
                FrameworkMediaDrm.DEFAULT_PROVIDER
            )
            .setKeyRequestParameters(drmKeyRequestProperties)
            .setMultiSession(false)
            .build(httpMediaDrmCallback)

        return DownloadHelper.forMediaItem(
            mediaItem,
            DownloadHelper.getDefaultTrackSelectorParameters(context),
            getRenderersFactory(context),
            defaultHttpDataSourceFactory,
            drmSessionManager
        )
    }

    private fun getRenderersFactory(context: Context): DefaultRenderersFactory {
        return DefaultRenderersFactory(context).setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF)
    }

    fun startDownload(raiDownloadItem: RaiDownloadItem, applicationContext: Context) {
        val downloadHelper = getDownloadHelper(
            applicationContext,
            MediaItem.fromUri(raiDownloadItem.downloadableUrl),
            raiDownloadItem.drmLicenseUrl ?: "",
            raiDownloadItem.drmOperator ?: ""
        )
        downloadHelper.prepare(object : DownloadHelper.Callback {
            override fun onPrepared(helper: DownloadHelper) {
                CoroutineScope(Dispatchers.IO).launch {

                    for (periodIndex in 0 until downloadHelper.periodCount) {
                        downloadHelper.clearTrackSelections(periodIndex)
                        val track = selectQuality(applicationContext, downloadHelper)
                        Log.d(TAG, "Quality track selected ${track.label}")

                        val newParameters = DownloadHelper.getDefaultTrackSelectorParameters(applicationContext)
                        val builder = newParameters.buildUpon()

                        builder.clearOverridesOfType(C.TRACK_TYPE_VIDEO)
                        builder.addOverride(
                            TrackSelectionOverride(
                                downloadHelper.getTrackGroups(periodIndex).get(track.trackInfo.groupIndex),
                                track.trackInfo.trackIndex
                            )
                        )
                        downloadHelper.addTrackSelection(periodIndex, builder.build())
                    }

                    //save subtitle
                    raiDownloadItem.downloadSubtitleList = saveSubtitle(
                        applicationContext,
                        raiDownloadItem.pathId ?: "",
                        raiDownloadItem.programPathId ?: "",
                        raiDownloadItem.downloadSubtitleList
                    )

                    val downloadRequest = downloadHelper.getDownloadRequest(
                        getId(raiDownloadItem),
                        Util.getUtf8Bytes(Gson().toJson(raiDownloadItem))
                    )
                    Log.d(TAG, "DownloadRequest $downloadRequest")
                    Log.d(TAG, "DownloadHelper $downloadHelper")
                    Log.d(TAG, "ApplicationContext $applicationContext")

                    DownloadService.sendAddDownload(
                        applicationContext,
                        RaiDownloadService::class.java,
                        downloadRequest,
                        false
                    )
                }
            }

            override fun onPrepareError(helper: DownloadHelper, e: IOException) {
                Log.e(TAG, "Error: while start download ${e.stackTrace}")
                downloadHelper.release()
            }
        })

        if (raiDownloadItem.drmLicenseUrl?.isNotBlank() == true) {
            val data = Data.Builder()
            data.putString(CONTENT_ITEM_ID, raiDownloadItem.contentItemId)
            data.putString(CONTENT_PATH_ID, raiDownloadItem.pathId)
            data.putString(PROGRAM_PATH_ID, raiDownloadItem.programPathId)
            data.putString(USER, raiDownloadItem.ua)
            data.putString(DOWNLOADABLE_URL, raiDownloadItem.downloadableUrl)
            data.putString(DRM_LICENSE_URL, raiDownloadItem.drmLicenseUrl)
            data.putString(DRM_LICENSE_OPERATOR, raiDownloadItem.drmOperator)

            val drmLicenseWorkRequest = OneTimeWorkRequestBuilder<DRMLicenseWorker>()
                .addTag(DRM_LICENSE_WORK_NAME)
                .setInputData(data.build())
                .build()

            WorkManager.getInstance(applicationContext).enqueueUniqueWork(
                DRM_LICENSE_WORK_NAME,
                ExistingWorkPolicy.APPEND_OR_REPLACE,
                drmLicenseWorkRequest
            )
        }
    }

    private fun selectQuality(context: Context, downloadHelper: DownloadHelper): Track {
        val qualityList = mutableListOf<Track>()
        val trackGroups = downloadHelper.getTrackGroups(0)
        val trackNameProvider = DefaultTrackNameProvider(context.resources)

        for (groupIndex in 0 until trackGroups.length) {
            val group = trackGroups[groupIndex]
            if (group.type == C.TRACK_TYPE_VIDEO) {
                for (trackIndex in 0 until group.length) {
                    val format = group.getFormat(trackIndex)
                    qualityList.add(
                        Track(
                            label = trackNameProvider.getTrackName(format),
                            trackInfo = ExoPlayerTrack(format = format, groupIndex = groupIndex, trackIndex = trackIndex),
                            isSelected = false
                        )
                    )
                    Log.d(TAG, "track: $groupIndex name: ${format.height}")
                }
            }
        }

        qualityList.sortByDescending { it.trackInfo.format.height }

        Log.d(TAG, "quality list size ${qualityList.size} - $qualityList")
        return when (qualityList.size) {
            1 -> qualityList[0]
            2 -> if (DOWNLOAD_QUALITY_REQUESTED == 0) qualityList[0] else qualityList[1]
            3 -> qualityList[DOWNLOAD_QUALITY_REQUESTED]
            else -> {
                when (DOWNLOAD_QUALITY_REQUESTED) {
                    0 -> qualityList[0]
                    2 -> qualityList.last()
                    else -> qualityList.getOrElse(qualityList.size - 2) { qualityList.last() }
                }
            }
        }
    }

    fun pauseDownload(item: RaiDownloadItem, context: Context) {
        val listItem = getStoredItem(item)
        DownloadService.sendSetStopReason(
            context,
            RaiDownloadService::class.java,
            getId(listItem),
            GENERIC_STOP_REASON,
            false
        )
    }

    fun resumeDownload(item: RaiDownloadItem, context: Context) {
        val listItem = getStoredItem(item)
        DownloadService.sendSetStopReason(
            context,
            RaiDownloadService::class.java,
            getId(listItem),
            EMPTY_STOP_REASON,
            false
        )
    }

    fun removeDownload(item: RaiDownloadItem, context: Context) {
        val listItem = getStoredItem(item)
        DownloadService.sendRemoveDownload(
            context,
            RaiDownloadService::class.java,
            getId(listItem),
            false
        )
    }

    fun resumeAllDownloads(context: Context) {
        DownloadService.sendResumeDownloads(
            context,
            RaiDownloadService::class.java,
            false
        )
    }

    fun getMediaItem(context: Context, item: RaiDownloadItem): MediaItem? {
        return if (item.drmLicenseUrl.isNullOrBlank())
            downloadManager.downloadIndex.getDownload(getId(item))?.request?.toMediaItem()
                ?: run {
                    Log.e(TAG, "Error can't find download with contentId: ${getId(item)}")
                    null
                }
        else createDrmMediaItem(context, getId(item), item.drmLicenseUrl!!)
    }

    fun getStoredItem(item: RaiDownloadItem): RaiDownloadItem {
        return downloadMap[getId(item, true)] ?: downloadMap[getIdWithoutProgram(item)] ?: item
    }


    fun createDrmMediaItem(context: Context, id: String, drmLicenseUrl: String): MediaItem? {
        return downloadManager.downloadIndex.getDownload(id)?.let {
            val drmTool = Util.getDrmUuid(DRM_LICENSE_WIDEVINE) ?: return null

            val drmConf = MediaItem.DrmConfiguration.Builder(drmTool)
                .setLicenseUri(drmLicenseUrl)
                .build()

            val builder = MediaItem.Builder()
            builder.setMediaId(it.request.id)
                .setUri(it.request.uri)
                .setCustomCacheKey(it.request.customCacheKey)
                .setMimeType(it.request.mimeType)
                .setStreamKeys(it.request.streamKeys)
                .setDrmConfiguration(
                    drmConf.buildUpon().setKeySetId(loadDrmLicense(context, id)).build()
                )
                .build()

        } ?: run {
            Log.e(TAG, "Error can't find download with contentId: $id")
            null
        }
    }


    //SUBTITLE
    private suspend fun saveSubtitle(
        context: Context,
        pathId: String,
        programPathId: String,
        downloadSubtitleList: List<RaiDownloadSubtitle>
    ): List<RaiDownloadSubtitle> {
        val newSubtitleList = mutableListOf<RaiDownloadSubtitle>()

        downloadSubtitleList.forEach { raiDownloadSubtitle ->
            if (raiDownloadSubtitle.language.isNotBlank() && raiDownloadSubtitle.webUrl.isNotBlank()) {
                val fileName =
                    (pathId + programPathId + raiDownloadSubtitle.language).hashCode().toString() + VIDEO_SUBTITLE + getMimeTypes(raiDownloadSubtitle.webUrl)
                val localUrl = downloadSubtitle(context, fileName, raiDownloadSubtitle.webUrl)

                if (localUrl.isNotBlank()) {
                    newSubtitleList.add(
                        RaiDownloadSubtitle(
                            raiDownloadSubtitle.language,
                            raiDownloadSubtitle.webUrl,
                            localUrl
                        )
                    )
                }
            }
        }

        return newSubtitleList
    }

    private suspend fun downloadSubtitle(
        context: Context,
        fileName: String,
        url: String,
    ): String {
        var savedSubtitlePath = ""
        var success = true
        val storageDir =
            File(context.filesDir.absolutePath + File.separator + RAI_DOWNLOAD_SUBTITLE_FOLDER)

        if (!storageDir.exists()) success = storageDir.mkdirs()

        if (success) {
            val subtitleFile = File(storageDir, fileName)
            savedSubtitlePath = subtitleFile.absolutePath

            raiDownloadRepository.getSubTitleFile(url).enqueue(object : Callback<ResponseBody> {
                override fun onResponse(
                    call: Call<ResponseBody>,
                    response: Response<ResponseBody>
                ) {
                    if (response.isSuccessful) {
                        var inputStream: InputStream? = null
                        var outputStream: OutputStream? = null
                        var writer: OutputStreamWriter? = null

                        try {
                            inputStream = response.body()?.byteStream()
                            outputStream = FileOutputStream(subtitleFile)

                            while (true) {
                                val read = inputStream?.read() ?: -1
                                val inputString =
                                    inputStream?.bufferedReader().use { it?.readText() } ?: ""

                                if (read == -1) {
                                    break
                                }

                                writer = OutputStreamWriter(outputStream, "UTF8")
                                writer.write(inputString)
                            }

                            writer?.flush()
                            outputStream.flush()
                        } catch (e: Exception) {
                            Log.e(TAG, "Error while saving subtitle, ${e.message}  ----  ${e.stackTrace}")
                        } finally {
                            inputStream?.close()
                            outputStream?.close()
                            writer?.close()
                        }
                    } else {
                        Log.e(TAG, "Error while call getSubtitleFile function")
                    }
                }

                override fun onFailure(call: Call<ResponseBody>, t: Throwable) {
                    Log.e(TAG, "Error while saving subtitle file: ${t.message}")
                    t.printStackTrace()
                }
            })
        } else {
            Log.e(TAG, "Error while creating subtitle folder")
        }

        return savedSubtitlePath
    }

    private fun deleteSubtitle(context: Context, downloadSubtitleList: List<RaiDownloadSubtitle>) {
        val storageDir =
            File(context.filesDir.absolutePath + File.separator + RAI_DOWNLOAD_SUBTITLE_FOLDER)

        downloadSubtitleList.forEach { raiDownloadSubtitle ->
            val fileName = raiDownloadSubtitle.localUrl

            if (storageDir.exists()) {
                val subtitleFile = File(fileName)

                if (subtitleFile.exists()) {
                    if (subtitleFile.delete()) Log.d(TAG, "File $fileName deleted")
                    else Log.e(TAG, "Error while deleting subtitle file $fileName")
                } else {
                    Log.e(
                        TAG,
                        "Error while deleting subtitle file $fileName, the file doesn't exist"
                    )
                }
            } else {
                Log.e(TAG, "Error while deleting subtitle file $fileName, directory doesn't exist")
            }
        }
    }

    //DRM LICENSE
    fun saveDrmLicense(
        context: Context,
        id: String,
        drmLicenseUrl: String,
        offlineLicenseKeySetId: ByteArray
    ) {
        Log.d(TAG, "save drm license")
        //update raiDownloadItem
        downloadMap[id]?.drmLicenseUrl = drmLicenseUrl

        //save byteArray
        val storageDir =
            File(context.filesDir.absolutePath + File.separator + RAI_DOWNLOAD_DRM_LICENSE_FOLDER)
        var success = true

        if (!storageDir.exists()) success = storageDir.mkdirs()

        if (success) {
            val drmLicenseFile = File(storageDir, "$DRM_LICENSE_PREFIX${id}")

            try {
                val fOut: OutputStream = FileOutputStream(drmLicenseFile)
                fOut.write(offlineLicenseKeySetId)
                fOut.close()
            } catch (e: Exception) {
                e.printStackTrace()
                Log.e(TAG, "Error while saving drm license")
            }
        }
    }

    private fun loadDrmLicense(context: Context, id: String): ByteArray? {
        val storageDir =
            File(context.filesDir.absolutePath + File.separator + RAI_DOWNLOAD_DRM_LICENSE_FOLDER)

        return if (storageDir.exists()) {
            val drmLicenseFile = File(storageDir, "$DRM_LICENSE_PREFIX${id}")

            if (drmLicenseFile.exists()) {
                drmLicenseFile.readBytes()
            } else {
                Log.e(TAG, "Error drm license doesn't exist")
                null
            }
        } else {
            null
        }
    }

    private fun deleteDrmLicense(context: Context, item: RaiDownloadItem) {
        val storageDir =
            File(context.filesDir.absolutePath + File.separator + RAI_DOWNLOAD_DRM_LICENSE_FOLDER)
        val id = getId(item)

        if (storageDir.exists()) {
            val drmLicenseFile = File(storageDir, "$DRM_LICENSE_PREFIX$id")
            if (drmLicenseFile.exists()) {
                if (drmLicenseFile.delete()) {
                    Log.d(
                        TAG,
                        "File $DRM_LICENSE_PREFIX$id deleted"
                    )
                } else Log.e(TAG, "Error while deleting drm file $DRM_LICENSE_PREFIX$id")
            } else {
                Log.e(
                    TAG,
                    "Error while deleting drm file $DRM_LICENSE_PREFIX$id, the file doesn't exist"
                )
            }
        } else {
            Log.e(TAG, "Error while deleting drm file directory doesn't exist")
        }
    }

    //TODO
    fun refreshDrmLicense(
        context: Context,
        item: RaiDownloadItem
    ) {
        deleteDrmLicense(context, item) //Delete OLD license

        val data = Data.Builder()
        data.putString(CONTENT_ITEM_ID, item.contentItemId)
        data.putString(CONTENT_PATH_ID, item.pathId)
        data.putString(PROGRAM_PATH_ID, item.programPathId)
        data.putString(USER, item.ua)
        data.putString(DOWNLOADABLE_URL, item.downloadableUrl)
        data.putString(DRM_LICENSE_URL, item.drmLicenseUrl)
        data.putString(DRM_LICENSE_OPERATOR, item.drmOperator)

        val refreshDrmLicenseWorkRequest = OneTimeWorkRequestBuilder<RefreshDRMLicenseWorker>()
            .addTag(DRM_LICENSE_WORK_NAME)
            .setInputData(data.build())
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            DRM_LICENSE_WORK_NAME,
            ExistingWorkPolicy.APPEND_OR_REPLACE,
            refreshDrmLicenseWorkRequest
        )
    }

    inner class DownloadManagerListener(private val context: Context) : DownloadManager.Listener {

        override fun onDownloadChanged(
            downloadManager: DownloadManager,
            download: Download,
            finalException: Exception?
        ) {
            super.onDownloadChanged(downloadManager, download, finalException)

            val raiDownloadItem = download.request.data.toRaiDownloadItem()

            raiDownloadItem?.run {
                state = download.toRaiDownloadState()
                downloadSizeMb = download.bytesDownloaded / (1024 * 1024)
                bytesDownloaded = download.bytesDownloaded
                if (state == RaiDownloadState.COMPLETED) totalBytes = download.bytesDownloaded
                else if (download.percentDownloaded.toLong() != 0L) totalBytes = download.bytesDownloaded * 100 / download.percentDownloaded.toLong()

                if (raiDownloadItem.state != RaiDownloadState.FAILED)
                    downloadMap[getId(raiDownloadItem, true)] = raiDownloadItem
                else {
                    downloadMap.remove(download.request.id)
                    CoroutineScope(Dispatchers.Default).launch {
                        errorDownloadFlow.emit(ErrorItem(raiDownloadItem.pathId ?: "", raiDownloadItem.programPathId ?: "", finalException?.message ?: ""))
                    }
                }

                postDownloadList()

                val downloading = downloadMap.filterValues { it.state == RaiDownloadState.DOWNLOADING }
                if (downloading.isNotEmpty()) startDownloadRunnable()
                else destroyDownloadRunnable()
            }
        }

        override fun onDownloadRemoved(downloadManager: DownloadManager, download: Download) {
            super.onDownloadRemoved(downloadManager, download)

            val raiDownloadItem = download.request.data.toRaiDownloadItem()

            raiDownloadItem?.run {

                deleteSubtitle(context, raiDownloadItem.downloadSubtitleList)
                if (raiDownloadItem.isDrm) deleteDrmLicense(context, raiDownloadItem)

                downloadMap.remove(getId(raiDownloadItem, true))
                postDownloadList()

                Log.d(TAG, "onDownloadRemoved ${getId(raiDownloadItem, true)}")
            }
        }
    }

    private fun getMimeTypes(url: String): String {
        return when {
            url.contains(SRT_EXT) -> SRT_EXT
            url.contains(VTT_EXT) -> VTT_EXT
            else -> ""
        }
    }

    fun getDownloadByPathId(pathId: String?): RaiDownloadItem? {
        return downloadMap[pathId]
    }

    fun getDownloadedUri(item: RaiDownloadItem?): Uri? {
        val download = downloadManager.downloadIndex.getDownload(getId(item!!, true))
        if (download != null && download.state == Download.STATE_COMPLETED) {
            return download.request.uri
        }
        return null
    }

    private fun getId(item: RaiDownloadItem, forcePathId: Boolean = false): String {//ID sarà solo pathId
//        return if (forcePathId) (item.ua + item.pathId + item.programPathId).hashCode().toString()
//        else
//            (item.contentItemId ?: (item.ua + item.pathId + item.programPathId).hashCode().toString())
        return item.pathId
    }

    private fun getIdWithoutProgram(item: RaiDownloadItem): String {
//        return (item.ua + item.pathId + "").hashCode().toString()
        return item.pathId
    }

    companion object {
        private const val SRT_EXT = ".srt"
        private const val VTT_EXT = ".vtt"
        private const val GENERIC_STOP_REASON = 1
        private const val EMPTY_STOP_REASON = 0
        private const val VIDEO_SUBTITLE = "_subtitle"
    }
}
