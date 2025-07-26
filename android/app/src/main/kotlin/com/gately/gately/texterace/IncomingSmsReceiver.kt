package com.gately.texterace

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import android.content.ContentValues
import android.provider.Telephony.Sms
import android.util.Log

class IncomingSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_RECEIVED_ACTION == intent.action) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)

            for (smsMessage in messages) {
                val address = smsMessage.displayOriginatingAddress
                val body = smsMessage.messageBody
                val timestamp = smsMessage.timestampMillis

                val values = ContentValues().apply {
                    put(Sms.ADDRESS, address)
                    put(Sms.BODY, body)
                    put(Sms.TYPE, Sms.MESSAGE_TYPE_INBOX)
                    put(Sms.DATE, timestamp)
                    put(Sms.READ, 0)
                    put(Sms.SEEN, 0)
                }

                // Only insert if default SMS app
                if (Telephony.Sms.getDefaultSmsPackage(context) == context.packageName) {
                    try {
                        val uri = context.contentResolver.insert(Sms.CONTENT_URI, values)
                        Log.d("IncomingSmsReceiver", "Inserted SMS: $uri")
                    } catch (e: Exception) {
                        Log.e("IncomingSmsReceiver", "Failed to insert SMS: ${e.message}")
                    }
                } else {
                    Log.d("IncomingSmsReceiver", "Not default SMS app; skipping insert")
                }
            }
        }
    }
}
