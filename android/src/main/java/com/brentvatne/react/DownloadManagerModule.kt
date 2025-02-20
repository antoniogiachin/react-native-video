package com.brentvatne.react

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import com.brentvatne.exoplayer.download.RaiDownloadTracker
import com.brentvatne.exoplayer.download.model.toRaiDownloadItem
import com.brentvatne.exoplayer.download.model.toReadableMap
import com.brentvatne.exoplayer.download.utils.DiUtils
import com.brentvatne.exoplayer.download.utils.DownloadConstants
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.modules.core.DeviceEventManagerModule

@UnstableApi
class DownloadManagerModule(private val reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String {
        return NAME
    }

    private var downloadTracker: RaiDownloadTracker? = null

    override fun initialize() {
        super.initialize()
        Log.d(NAME, "init")
        downloadTracker = DiUtils.getDownloadTracker(reactContext)
        downloadTracker?.subscribeDownloads {
            val readableArray = Arguments.createArray()
            it.forEach { item ->
                readableArray.pushMap(item.toReadableMap())
            }
            reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                .emit("onDownloadListChanged", readableArray)
        }
        downloadTracker?.subscribeError {
            val readableMap = Arguments.createMap()
            readableMap.putString("pathId", it.pathId)
            readableMap.putString("programPathId", it.programPathId)
            readableMap.putString("message", it.message)
            reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                .emit("onDownloadError", readableMap)
        }
        downloadTracker?.subscribeRenewLicense {
            val readableMap = Arguments.createMap()
            readableMap.putMap("item", it.item.toReadableMap())
            readableMap.putBoolean("result", it.result)
            reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                .emit("onRenewLicense", readableMap)
        }
        downloadTracker?.retrieveDownloads(reactContext)
    }

    @OptIn(UnstableApi::class)
    @ReactMethod
    fun prepare() {

    }

    @ReactMethod
    fun start(item: ReadableMap) {
        Log.d(NAME, "start $item")
        createNotificationChannel()
        downloadTracker?.startDownload(item.toRaiDownloadItem(), reactContext)
    }

    @ReactMethod
    fun resume(item: ReadableMap) {
        Log.d(NAME, "resume $item")
        downloadTracker?.resumeDownload(item.toRaiDownloadItem(), reactContext)
    }

    @ReactMethod
    fun pause(item: ReadableMap) {
        Log.d(NAME, "pause $item")
        downloadTracker?.pauseDownload(item.toRaiDownloadItem(), reactContext)
    }

    @ReactMethod
    fun delete(item: ReadableMap) {
        Log.d(NAME, "delete $item")
        downloadTracker?.removeDownload(item.toRaiDownloadItem(), reactContext)
    }

    @ReactMethod
    fun renewDrmLicense(item: ReadableMap) {
        Log.d(NAME, "renewDrmLicense $item")
        val downloadItem = item.toRaiDownloadItem()
        downloadTracker?.refreshDrmLicense(reactContext, downloadItem)
    }

    @ReactMethod
    fun setQuality(quality: String) {
        Log.d(NAME, "setQuality $quality")
        when (quality) {
            "High" -> DOWNLOAD_QUALITY_REQUESTED = 2
            "Medium" -> DOWNLOAD_QUALITY_REQUESTED = 1
            "Low" -> DOWNLOAD_QUALITY_REQUESTED = 0
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                DownloadConstants.DOWNLOAD_CHANNEL_ID,
                DownloadConstants.DOWNLOAD_NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                this.description = DownloadConstants.DOWNLOAD_NOTIFICATION_CHANNEL_DESC
            }
            val notificationManager: NotificationManager =
                reactContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannels(listOf(channel))
        }
    }

    companion object {
        const val NAME = "DownloadManagerModule"
        var DOWNLOAD_QUALITY_REQUESTED = 2
    }


}
