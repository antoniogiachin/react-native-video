package com.brentvatne.react

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.media3.common.util.UnstableApi
import com.brentvatne.exoplayer.download.RaiDownloadTracker
import com.brentvatne.exoplayer.download.model.RaiDownloadState
import com.brentvatne.exoplayer.download.model.react.toReactDownloadItem
import com.brentvatne.exoplayer.download.model.toRaiDownloadItem
import com.brentvatne.exoplayer.download.model.toReadableMap
import com.brentvatne.exoplayer.download.utils.DiUtils
import com.brentvatne.exoplayer.download.utils.DownloadConstants
import com.brentvatne.exoplayer.download.utils.toRaiDownloadItem
import com.brentvatne.exoplayer.download.utils.toReactDownloadItem
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@UnstableApi
class DownloadManagerModule(private val reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String {
        return NAME
    }

    private var downloadTracker: RaiDownloadTracker? = null
    private var listenerCount = 0


    override fun initialize() {
        super.initialize()
        Log.d(NAME, "init")
        downloadTracker = DiUtils.getDownloadTracker(reactContext)
        downloadTracker?.subscribeDownloads {
            val readableArray = Arguments.createArray()
            it.forEach { item ->
                readableArray.pushMap(item.toReactDownloadItem().toReadableMap())
            }
            Log.d(NAME, "onDownloadListChanged $readableArray")
            reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                .emit("onDownloadListChanged", readableArray)
        }

        downloadTracker?.subscribeProgress {
            val readableArray = Arguments.createArray()
            it.forEach { item ->
                readableArray.pushMap(item.toReactDownloadItem().toReadableMap())
            }
            Log.d(NAME, "onDownloadProgress $readableArray")
            reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                .emit("onDownloadProgress", readableArray)
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

    @ReactMethod
    fun start(item: ReadableMap) {
        Log.d(NAME, "start $item")
        createNotificationChannel()
        downloadTracker?.startDownload(item.toReactDownloadItem().toRaiDownloadItem(), reactContext)
    }

    @ReactMethod
    fun resume(item: ReadableMap) {
        Log.d(NAME, "resume $item")
        downloadTracker?.resumeDownload(
            item.toReactDownloadItem().toRaiDownloadItem(),
            reactContext
        )
    }

    @ReactMethod
    fun pause(item: ReadableMap) {
        Log.d(NAME, "pause $item")
        downloadTracker?.pauseDownload(item.toReactDownloadItem().toRaiDownloadItem(), reactContext)
    }

    @ReactMethod
    fun delete(item: ReadableMap) {
        Log.d(NAME, "delete $item")
        downloadTracker?.removeDownload(
            item.toReactDownloadItem().toRaiDownloadItem(),
            reactContext
        )
    }

//    fun renewDrmLicense(item: ReadableMap) {
//        Log.d(NAME, "renewDrmLicense $item")
//        val downloadItem = item.toRaiDownloadItem()
//        downloadTracker?.refreshDrmLicense(reactContext, downloadItem)
//    }

    @ReactMethod
    fun setQuality(quality: String) {
        Log.d(NAME, "setQuality $quality")
        when (quality) {
            "High" -> DOWNLOAD_QUALITY_REQUESTED = 2
            "Medium" -> DOWNLOAD_QUALITY_REQUESTED = 1
            "Low" -> DOWNLOAD_QUALITY_REQUESTED = 0
        }
    }

    @ReactMethod
    fun batchDelete(items: ReadableArray) {
        Log.d(NAME, "batch delete $items")
        for (i in 0 until items.size()) {
            val item = items.getMap(i)
            downloadTracker?.removeDownload(item.toRaiDownloadItem(), reactContext)
        }
    }

    @ReactMethod
    fun getDownloadList(ua: String, promise: Promise) {
        Log.d(NAME, "getDownloadList")
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val list = downloadTracker?.getDownloadMap()?.values?.toList()?.filter { it.state == RaiDownloadState.COMPLETED && it.ua == ua }
                val array = Arguments.createArray()

                if (list != null) {
                    for(item in list){
                        array.pushMap(item.toReactDownloadItem().toWritableMap())
                    }
                }

                withContext(Dispatchers.Main) {
                    promise.resolve(array)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    promise.reject("DOWNLOAD_ERROR", e)
                }
            }
        }
    }

    @ReactMethod
    fun addListener(eventName: String?) {
        listenerCount += 1
    }

    @ReactMethod
    fun removeListeners(count: Int) {
        listenerCount -= count
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
