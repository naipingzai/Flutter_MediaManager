package com.naipingzai.flutter_media_view.channel.streams.platformtodart

import com.naipingzai.flutter_media_view.channel.streams.BaseStreamHandler
import com.naipingzai.flutter_media_view.utils.LogUtils

class IntentStreamHandler : BaseStreamHandler() {
    fun notifyNewIntent(intentData: MutableMap<String, Any?>?) = success(intentData)

    override val logTag = LOG_TAG

    companion object {
        private val LOG_TAG = LogUtils.createTag<IntentStreamHandler>()
        const val CHANNEL = "deckers.thibault/aves/new_intent_stream"
    }
}