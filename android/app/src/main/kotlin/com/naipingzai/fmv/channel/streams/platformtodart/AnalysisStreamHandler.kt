package com.naipingzai.fmv.channel.streams.platformtodart

import com.naipingzai.fmv.channel.streams.BaseStreamHandler
import com.naipingzai.fmv.utils.LogUtils

class AnalysisStreamHandler : BaseStreamHandler() {
    fun notifyCompletion() = success(true)

    override val logTag = LOG_TAG

    companion object {
        private val LOG_TAG = LogUtils.createTag<AnalysisStreamHandler>()
        const val CHANNEL = "com.naipingzai.fmv/analysis_events"
    }
}