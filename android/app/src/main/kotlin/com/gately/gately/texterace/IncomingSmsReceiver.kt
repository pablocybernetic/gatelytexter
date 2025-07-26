package com.gately.texterace

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import android.content.ContentValues
import android.provider.Telephony.Sms
import androidx.core.app.NotificationCompat

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

                // Notify Flutter via EventChannel
                MainActivity.sendIncomingSmsToFlutter(address, body, timestamp)

                // Show notification
                showNotification(context, address, body)
            }
        }
    }

    private fun showNotification(context: Context, address: String, message: String) {
        val channelId = "sms_channel_id"
        val channelName = "SMS Notifications"

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH)
            channel.enableLights(true)
            channel.lightColor = Color.BLUE
            channel.enableVibration(true)
            channel.description = "Incoming SMS messages"
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.sym_action_chat)
            .setContentTitle("New SMS from $address")
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }
}
