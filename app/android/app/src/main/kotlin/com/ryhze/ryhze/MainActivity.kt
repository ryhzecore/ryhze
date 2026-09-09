package com.ryhze.ryhze

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ryhze.ryhze/updates")
            .setMethodCallHandler { call, result ->
                if (call.method != "install") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val file = File(call.argument<String>("path") ?: "").canonicalFile
                    val folder = File(cacheDir, "ryhze-updates").canonicalFile
                    require(file.parentFile == folder && file.isFile && file.extension == "apk") { "Invalid update file" }
                    @Suppress("DEPRECATION")
                    val flags = PackageManager.GET_SIGNATURES
                    @Suppress("DEPRECATION")
                    val archive = packageManager.getPackageArchiveInfo(file.path, flags)
                        ?: error("Invalid APK")
                    @Suppress("DEPRECATION")
                    val installed = packageManager.getPackageInfo(packageName, flags)
                    require(archive.packageName == packageName) { "Wrong application" }
                    @Suppress("DEPRECATION")
                    require(archive.signatures?.toSet() == installed.signatures?.toSet() && !archive.signatures.isNullOrEmpty()) { "Update signer differs" }
                    @Suppress("DEPRECATION")
                    val newVersion = if (Build.VERSION.SDK_INT >= 28) archive.longVersionCode else archive.versionCode.toLong()
                    @Suppress("DEPRECATION")
                    val oldVersion = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
                    require(newVersion > oldVersion) { "Update must be newer" }
                    if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                        result.success("permission")
                    } else {
                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success("installer")
                    }
                } catch (error: Exception) {
                    result.error("UPDATE_INSTALL", error.message ?: "Installation unavailable", null)
                }
            }
    }
}
