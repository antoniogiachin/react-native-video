package com.brentvatne.exoplayer.download.model

data class Track(
    val label: String,
    val trackInfo: ExoPlayerTrack,
    var isSelected: Boolean
)
