package app.threeapes.client

import android.annotation.SuppressLint
import android.app.AppOpsManager
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.elvishew.xlog.XLog
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import app.threeapes.client.pigeon.AppFlutterApi
import app.threeapes.client.pigeon.AppHostApi
import app.threeapes.client.pigeon.BridgeHostApi
import app.threeapes.client.pigeon.BackupHostApi
import app.threeapes.client.pigeon.BackupApi
import app.threeapes.client.vpn.OneVpnService
import app.threeapes.client.automation.AutomationApi
import app.threeapes.client.pigeon.AndroidAutomationHostApi

class MainActivity : FlutterFragmentActivity() {

    private val hostApi = AppHostApi(this)
    private val backupApi = BackupApi(this)
    private var vpnStatusReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        registerVpnStatusReceiver()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val flutterApi = AppFlutterApi(flutterEngine.dartExecutor)
        BridgeHostApi.setUp(flutterEngine.dartExecutor, hostApi)
        BackupHostApi.setUp(flutterEngine.dartExecutor, backupApi)
        AndroidAutomationHostApi.setUp(flutterEngine.dartExecutor, AutomationApi(this))
        // 3 APES: системный идентификатор устройства для постоянного HWID
        // (в Dart хешируется с солью, сам ANDROID_ID никуда не отправляется).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.threeapes.client/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "androidId" -> result.success(androidId())
                    // 3 APES: Always-on VPN and "Block connections without VPN"
                    // can only be switched on by the user in system settings.
                    "openVpnSettings" -> result.success(
                        try {
                            startActivity(
                                Intent(Settings.ACTION_VPN_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            true
                        } catch (_: Exception) {
                            false
                        }
                    )
                    // 3 APES: security check — DNS of the active network.
                    "networkDns" -> result.success(networkDns())
                    // 3 APES: security check — device state; the app list is
                    // read off the main thread.
                    "deviceSecurity" -> Thread {
                        val info = deviceSecurity()
                        runOnUiThread { result.success(info) }
                    }.start()
                    "openSettings" -> result.success(
                        openSettings(call.argument<String>("which"))
                    )
                    else -> result.notImplemented()
                }
            }

        hostApi.onInit(flutterApi)
    }

    // 接收器在 onCreate 中注册、onDestroy 中注销，避免在 onPause（系统弹窗导致 Activity 暂停）
    // 期间错过 OneVpnService 发出的 VPN 状态广播，否则 Dart 侧会因收不到 CONNECTED 而超时断开。
    @SuppressLint("UnspecifiedRegisterReceiverFlag")
    private fun registerVpnStatusReceiver() {
        if (vpnStatusReceiver != null) {
            return
        }
        vpnStatusReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == OneVpnService.ACTION_VPN_STATUS) {
                    val running = intent.getBooleanExtra(OneVpnService.EXTRA_RUNNING, false)
                    XLog.d("MainActivity: received VPN status changed: $running")
                    // 将状态交给现有 hostApi（可触发 Flutter 通知或内部状态更新）
                    hostApi.onVpnStatusChanged(running, intent.getStringExtra(OneVpnService.EXTRA_ERROR))
                }
            }
        }
        val filter = IntentFilter(OneVpnService.ACTION_VPN_STATUS).apply {
            priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        }
        vpnStatusReceiver?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(it, filter, RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(it, filter)
            }
        }
    }

    /// 3 APES: what Android uses for DNS right now. Read only; nothing is sent.
    private fun networkDns(): Map<String, Any?>? {
        return try {
            val cm = getSystemService(ConnectivityManager::class.java) ?: return null
            val network = cm.activeNetwork ?: return null
            val caps = cm.getNetworkCapabilities(network)
            val link = cm.getLinkProperties(network)
            mapOf(
                "vpn" to (caps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true),
                "servers" to (link?.dnsServers?.mapNotNull { it.hostAddress } ?: emptyList<String>()),
                "privateDns" to (link?.isPrivateDnsActive == true),
                "privateDnsName" to link?.privateDnsServerName,
            )
        } catch (_: Exception) {
            null
        }
    }

    /// 3 APES: screen lock, security patch, developer options, apps that
    /// may install other apps, Always-on VPN. Read only; nothing is sent.
    private fun deviceSecurity(): Map<String, Any?> {
        val keyguard = getSystemService(KeyguardManager::class.java)
        val vpn = OneVpnService.current
        return mapOf(
            "screenLock" to keyguard?.isDeviceSecure,
            "securityPatch" to Build.VERSION.SECURITY_PATCH,
            "developerOptions" to (globalInt(Settings.Global.DEVELOPMENT_SETTINGS_ENABLED) == 1),
            "adb" to (globalInt(Settings.Global.ADB_ENABLED) == 1 || globalInt("adb_wifi_enabled") == 1),
            "installers" to installerApps(),
            "alwaysOn" to vpn?.isAlwaysOn,
            "lockdown" to vpn?.isLockdownEnabled,
        )
    }

    private fun globalInt(name: String): Int = try {
        Settings.Global.getInt(contentResolver, name, 0)
    } catch (_: Exception) {
        0
    }

    /// Apps (not the Play Store, not us) allowed to install other apps.
    @Suppress("DEPRECATION")
    private fun installerApps(): List<String>? = try {
        val pm = packageManager
        val ops = getSystemService(AppOpsManager::class.java)
        pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
            .filter { p ->
                p.packageName != packageName &&
                    p.packageName != "com.android.vending" &&
                    p.requestedPermissions?.contains("android.permission.REQUEST_INSTALL_PACKAGES") == true
            }
            .mapNotNull { p ->
                val app = p.applicationInfo ?: return@mapNotNull null
                val mode = ops?.unsafeCheckOpNoThrow(
                    "android:request_install_packages", app.uid, p.packageName
                )
                if (mode == AppOpsManager.MODE_ALLOWED) pm.getApplicationLabel(app).toString() else null
            }
            .sorted()
    } catch (_: Exception) {
        null
    }

    private fun openSettings(which: String?): Boolean {
        val action = when (which) {
            "security" -> Settings.ACTION_SECURITY_SETTINGS
            "developer" -> Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS
            "unknownSources" -> Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES
            "vpn" -> Settings.ACTION_VPN_SETTINGS
            else -> return false
        }
        return try {
            startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: Exception) {
            false
        }
    }

    @SuppressLint("HardwareIds")
    private fun androidId(): String? =
        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)

    override fun onDestroy() {
        backupApi.dispose()
        hostApi.onDestroy()
        // 防御式注销
        vpnStatusReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        vpnStatusReceiver = null
        super.onDestroy()
    }
}
