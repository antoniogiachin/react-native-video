package com.brentvatne.exoplayer.download.model

import android.os.Parcel
import android.os.Parcelable

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

    companion object CREATOR : Parcelable.Creator<RaiDownloadSubtitle> {
        override fun createFromParcel(parcel: Parcel): RaiDownloadSubtitle {
            return RaiDownloadSubtitle(parcel)
        }

        override fun newArray(size: Int): Array<RaiDownloadSubtitle?> {
            return arrayOfNulls(size)
        }
    }
}
