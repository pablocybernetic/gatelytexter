package com.gately.texterace

import android.app.role.RoleManager
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "sms_handler"
    private val SMS_DB_CHANNEL = "sms_system_db"
    private val REQUEST_DEFAULT_SMS_APP = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Existing SMS handler channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultSmsApp" -> {
                    val defaultSmsPackage = Telephony.Sms.getDefaultSmsPackage(this)
                    result.success(packageName == defaultSmsPackage)
                }
                "promptDefaultSmsApp" -> {
                    pendingResult = result
                    requestDefaultSmsApp()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // New SMS database channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_DB_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "insertSms" -> {
                    val success = insertSmsToSystem(call.arguments as Map<String, Any>)
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

private fun insertSmsToSystem(arguments: Map<String, Any>): Boolean {
    return try {
        // Check if we're the default SMS app
        val defaultSmsPackage = Telephony.Sms.getDefaultSmsPackage(this)
        if (packageName != defaultSmsPackage) {
            println("Not the default SMS app, cannot write to SMS database")
            return false
        }

        val type = (arguments["type"] as Number).toInt()
        val date = (arguments["date"] as Number).toLong()

        val values = ContentValues().apply {
            put(Telephony.Sms.ADDRESS, arguments["address"] as String)
            put(Telephony.Sms.BODY, arguments["body"] as String)
            put(Telephony.Sms.TYPE, type)
            put(Telephony.Sms.DATE, date)
            put(Telephony.Sms.DATE_SENT, date)
            put(Telephony.Sms.READ, if (type == 2) 1 else 0)
            put(Telephony.Sms.SEEN, 1)
            put(Telephony.Sms.STATUS, if (type == 2) Telephony.Sms.STATUS_COMPLETE else Telephony.Sms.STATUS_NONE)

            arguments["thread_id"]?.let { threadId ->
                put(Telephony.Sms.THREAD_ID, (threadId as Number).toLong())
            }
        }

        val uri = contentResolver.insert(Telephony.Sms.CONTENT_URI, values)
        val success = uri != null

        if (success) {
            println("Successfully inserted SMS into system database: $uri")
        } else {
            println("Failed to insert SMS into system database")
        }

        success
    } catch (e: Exception) {
        println("Exception inserting SMS to system database: ${e.message}")
        e.printStackTrace()
        false
    }
}


    private fun requestDefaultSmsApp() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_SMS)) {
                if (!roleManager.isRoleHeld(RoleManager.ROLE_SMS)) {
                    val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
                    startActivityForResult(intent, REQUEST_DEFAULT_SMS_APP)
                } else {
                    pendingResult?.success(true)
                    pendingResult = null
                }
            }
        } else {
            val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
            intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
            startActivityForResult(intent, REQUEST_DEFAULT_SMS_APP)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_DEFAULT_SMS_APP) {
            val defaultSmsPackage = Telephony.Sms.getDefaultSmsPackage(this)
            val isNowDefault = packageName == defaultSmsPackage
            pendingResult?.success(isNowDefault)
            pendingResult = null
        }
    }
}