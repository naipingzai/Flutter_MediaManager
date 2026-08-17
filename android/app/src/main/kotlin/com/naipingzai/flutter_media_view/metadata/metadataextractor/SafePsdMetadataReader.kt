package com.naipingzai.flutter_media_view.metadata.metadataextractor

import com.drew.lang.StreamReader
import com.drew.metadata.Metadata
import java.io.InputStream

object SafePsdMetadataReader {
    fun readMetadata(inputStream: InputStream): Metadata {
        val metadata = Metadata()
        SafePsdReader().extract(StreamReader(inputStream), metadata)
        return metadata
    }
}