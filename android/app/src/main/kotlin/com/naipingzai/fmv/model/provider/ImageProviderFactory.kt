package com.naipingzai.fmv.model.provider

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import com.naipingzai.fmv.utils.StorageUtils
import java.util.Locale

object ImageProviderFactory {
    fun getProvider(context: Context, uri: Uri): ImageProvider? {
        return when (uri.scheme?.lowercase(Locale.ROOT)) {
            ContentResolver.SCHEME_CONTENT -> {
                if (StorageUtils.isMediaStoreContentUri(uri)) {
                    MediaStoreImageProvider()
                } else if (FmvEmbeddedMediaProvider.provides(context, uri)) {
                    FmvEmbeddedMediaProvider()
                } else {
                    UnknownContentProvider()
                }
            }

            ContentResolver.SCHEME_FILE -> FileImageProvider()
            else -> null
        }
    }
}