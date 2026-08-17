package com.naipingzai.flutter_media_view.decoding

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Rect
import android.net.Uri
import com.naipingzai.flutter_media_view.channel.streams.darttoplatform.ByteSink
import com.naipingzai.flutter_media_view.glide.TiffFetcher
import com.naipingzai.flutter_media_view.utils.BitmapUtils
import com.naipingzai.flutter_media_view.utils.MimeTypes
import org.beyka.tiffbitmapfactory.DecodeArea
import org.beyka.tiffbitmapfactory.TiffBitmapFactory
import java.io.ByteArrayInputStream

class TiffRegionFetcher internal constructor(
    private val context: Context,
) {
    suspend fun fetch(
        uri: Uri,
        page: Int,
        decoded: Boolean,
        sampleSize: Int,
        regionRect: Rect,
        result: ByteSink,
    ) {
        try {
            val pfd = context.contentResolver.openFileDescriptor(uri, "r")
            if (pfd == null) {
                result.error("fetch-fd", "failed to get file descriptor for uri=$uri", null)
                return
            }
            pfd.use {
                val fd = pfd.detachFd()
                val options = TiffFetcher.buildOptions().apply {
                    inDirectoryNumber = page
                    inSampleSize = sampleSize
                    inDecodeArea = DecodeArea(regionRect.left, regionRect.top, regionRect.width(), regionRect.height())
                }
                val bitmap: Bitmap? = TiffBitmapFactory.decodeFileDescriptor(fd, options)
                val bytes = BitmapUtils.getBytes(bitmap, recycle = true, decoded = decoded, applyGainmap = false, mimeType = MimeTypes.TIFF)
                if (bytes == null) {
                    result.error("fetch-null", "failed to decode region for uri=$uri page=$page regionRect=$regionRect", null)
                } else {
                    result.streamBytes(ByteArrayInputStream(bytes))
                }
            }
        } catch (e: Exception) {
            result.error("fetch-exception", "failed to read from uri=$uri page=$page regionRect=$regionRect", e.message)
        }
    }
}
