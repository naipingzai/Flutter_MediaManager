package com.naipingzai.flutter_media_view.channel.streams.platformtodart

import com.naipingzai.flutter_media_view.channel.streams.BaseStreamHandler
import com.naipingzai.flutter_media_view.utils.LogUtils

class ErrorStreamHandler : BaseStreamHandler() {
    fun notifyError(error: String) = success(error)

    override val logTag = LOG_TAG

    companion object {
        private val LOG_TAG = LogUtils.createTag<ErrorStreamHandler>()
        const val CHANNEL = "deckers.thibault/aves/error"
    }
}