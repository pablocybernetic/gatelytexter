package com.gately.texterace

import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "sms_handler"
    private val REQUEST_DEFAULT_SMS_APP = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
