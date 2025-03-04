package com.brentvatne.exoplayer.download.model

import androidx.media3.common.Format

data class ExoPlayerTrack(
    val format: Format,
    val groupIndex: Int,
    val trackIndex: Int
)
