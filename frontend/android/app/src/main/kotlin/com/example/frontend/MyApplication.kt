package com.example.frontend

import android.app.Application
import com.zing.zalo.zalosdk.oauth.ZaloSDKApplication

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ZaloSDKApplication.wrap(this)
    }
}
