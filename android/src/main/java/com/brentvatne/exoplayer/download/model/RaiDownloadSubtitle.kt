package com.brentvatne.exoplayer.download.model

import android.os.Parcel
import android.os.Parcelable
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableMap

data class RaiDownloadSubtitle(
    var language: String,
    var webUrl: String,
    var localUrl: String
) : Parcelable {
    constructor(parcel: Parcel) : this(
        parcel.readString() ?: "",
        parcel.readString() ?: "",
        parcel.readString() ?: "",
    )

    override fun writeToParcel(parcel: Parcel, flags: Int) {
        parcel.writeString(language)
        parcel.writeString(webUrl)
        parcel.writeString(localUrl)
    }

    override fun describeContents(): Int {
        return 0
    }

    fun toWritableMap(): ReadableMap? {
        val map = Arguments.createMap()
        map.putString("language", language)
        map.putString("webUrl", webUrl)
        map.putString("localUrl", localUrl)
        return map
    }

    fun toReadableMap(): ReadableMap? {
        val map = Arguments.createMap()
        map.putString("language", language)
        map.putString("webUrl", webUrl)
        map.putString("localUrl", localUrl)
        return map
    }

    companion object CREATOR : Parcelable.Creator<RaiDownloadSubtitle> {
        override fun createFromParcel(parcel: Parcel): RaiDownloadSubtitle {
            return RaiDownloadSubtitle(parcel)
        }

        override fun newArray(size: Int): Array<RaiDownloadSubtitle?> {
            return arrayOfNulls(size)
        }
    }
}
