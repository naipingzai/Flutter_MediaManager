package com.naipingzai.fmv.channel.streams.platformtodart

import com.naipingzai.fmv.channel.streams.BaseStreamHandler
import com.naipingzai.fmv.utils.LogUtils

class IntentStreamHandler : BaseStreamHandler() {
    fun notifyNewIntent(intentData: MutableMap<String, Any?>?) = success(intentData)

    override val logTag = LOG_TAG

    companion object {
        private val LOG_TAG = LogUtils.createTag<IntentStreamHandler>()
        const val CHANNEL = "com.naipingzai.fmv/new_intent_stream"
    }
}