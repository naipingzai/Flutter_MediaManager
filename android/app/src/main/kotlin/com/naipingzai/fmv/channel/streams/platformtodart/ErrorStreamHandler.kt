package com.naipingzai.fmv.channel.streams.platformtodart

import com.naipingzai.fmv.channel.streams.BaseStreamHandler
import com.naipingzai.fmv.utils.LogUtils

class ErrorStreamHandler : BaseStreamHandler() {
    fun notifyError(error: String) = success(error)

    override val logTag = LOG_TAG

    companion object {
        private val LOG_TAG = LogUtils.createTag<ErrorStreamHandler>()
        const val CHANNEL = "com.naipingzai.fmv/error"
    }
}