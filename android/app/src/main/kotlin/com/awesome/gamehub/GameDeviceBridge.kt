package com.awesome.gamehub

import android.Manifest
import android.app.Activity
import android.bluetooth.*
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class GameDeviceBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val handler = Handler(Looper.getMainLooper())
    private var pendingPermission: MethodChannel.Result? = null
    private var pendingAction: String? = null
    private var pendingRead: MethodChannel.Result? = null
    private var connection: BluetoothGatt? = null
    private var timeout: Runnable? = null
    private val values = mutableMapOf<String, Any>()
    private val queue = java.util.ArrayDeque<BluetoothGattCharacteristic>()
    private val batteryId = uuid("2a19")
    private val firmwareId = uuid("2a26")
    private val manufacturerId = uuid("2a29")
    private val modelId = uuid("2a24")
    private val adapter get() = (activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    private fun uuid(short: String) = UUID.fromString("0000$short-0000-1000-8000-00805f9b34fb")
    private fun permitted() = Build.VERSION.SDK_INT < 31 || activity.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    init {
        MethodChannel(messenger, "ludivex/devices").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (permitted()) {
                        result.success(true)
                    } else if (pendingPermission != null) {
                        result.success(false)
                    } else {
                        pendingPermission = result
                        pendingAction = "permission"
                        activity.requestPermissions(
                            if (Build.VERSION.SDK_INT >= 31) arrayOf(
                                Manifest.permission.BLUETOOTH_CONNECT,
                                Manifest.permission.BLUETOOTH_SCAN
                            ) else arrayOf(Manifest.permission.BLUETOOTH),
                            7214
                        )
                    }
                }
                "scan" -> {
                    if (pendingPermission != null) result.error("BUSY", "Permissão em andamento.", null)
                    else if (!permitted()) {
                        pendingPermission = result
                        pendingAction = "scan"
                        activity.requestPermissions(
                            if (Build.VERSION.SDK_INT >= 31) arrayOf(
                                Manifest.permission.BLUETOOTH_CONNECT,
                                Manifest.permission.BLUETOOTH_SCAN
                            ) else arrayOf(Manifest.permission.BLUETOOTH),
                            7214
                        )
                    } else scan(result)
                }
                "readDetails" -> {
                    val id = call.argument<String>("id")
                    if (!permitted()) result.error("PERMISSION", "Permita o acesso aos dispositivos próximos.", null)
                    else if (id == null || !android.bluetooth.BluetoothAdapter.checkBluetoothAddress(id)) result.error("INVALID_ID", "Dispositivo inválido.", null)
                    else read(id, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onPermissionResult(requestCode: Int, granted: IntArray) {
        if (requestCode != 7214) return
        val result = pendingPermission ?: return
        val action = pendingAction
        pendingPermission = null
        pendingAction = null
        val isGranted = granted.isNotEmpty() && granted[0] == PackageManager.PERMISSION_GRANTED
        if (action == "permission") {
            result.success(isGranted)
        } else {
            if (isGranted) scan(result)
            else result.error("PERMISSION", "Acesso ao Bluetooth não autorizado.", null)
        }
    }

    @Suppress("MissingPermission")
    private fun scan(result: MethodChannel.Result) {
        try {
            val bluetooth = adapter
            if (bluetooth == null || !bluetooth.isEnabled) {
                result.error("DISABLED", "Ligue o Bluetooth nas configurações do celular.", null)
                return
            }
            val devices = bluetooth.bondedDevices.mapNotNull { device ->
                val name = device.name ?: "Dispositivo Bluetooth"
                val major = device.bluetoothClass?.majorDeviceClass
                val deviceClass = device.bluetoothClass?.deviceClass ?: -1
                val lower = name.lowercase()
                val kind = when {
                    Regex("controller|gamepad|dualsense|dualshock|xbox|8bitdo|gamesir").containsMatchIn(lower) -> "controller"
                    major == BluetoothClass.Device.Major.AUDIO_VIDEO && deviceClass in listOf(
                        BluetoothClass.Device.AUDIO_VIDEO_WEARABLE_HEADSET, BluetoothClass.Device.AUDIO_VIDEO_HEADPHONES,
                        BluetoothClass.Device.AUDIO_VIDEO_HANDSFREE) -> "headset"
                    major == BluetoothClass.Device.Major.PERIPHERAL &&
                        ((deviceClass and 0x3c) == 0x04 || (deviceClass and 0x3c) == 0x08) -> "controller"
                    else -> null
                }
                if (kind == null) null else {
                    val battery: Int? = try {
                        val method = device.javaClass.getMethod("getBatteryLevel")
                        val level = method.invoke(device) as? Int
                        if (level != null && level in 0..100) level else null
                    } catch (_: Exception) { null }
                    val map = mutableMapOf<String, Any>(
                        "id" to device.address,
                        "name" to name,
                        "kind" to kind,
                        "gattReadable" to (device.type == BluetoothDevice.DEVICE_TYPE_LE || device.type == BluetoothDevice.DEVICE_TYPE_DUAL)
                    )
                    if (battery != null) map["battery"] = battery
                    map
                }
            }.sortedBy { it["name"].toString() }
            result.success(devices)
        } catch (error: Exception) { result.error("SCAN_FAILED", "Não foi possível consultar o Bluetooth.", null) }
    }

    @Suppress("MissingPermission")
    private fun read(id: String, result: MethodChannel.Result) {
        if (pendingRead != null) { result.error("BUSY", "Outra leitura está em andamento.", null); return }
        pendingRead = result
        values.clear()
        queue.clear()
        try {
            val device = adapter?.bondedDevices?.firstOrNull { it.address == id }
            if (device == null) { pendingRead = null; result.error("NOT_PAIRED", "Dispositivo não pareado.", null); return }
            timeout = Runnable { finish() }.also { handler.postDelayed(it, 9000) }
            connection = device.connectGatt(activity, false, callback, BluetoothDevice.TRANSPORT_LE)
            if (connection == null) finish()
        } catch (error: Exception) { finish() }
    }

    private val callback = object : BluetoothGattCallback() {
        @Suppress("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, state: Int) {
            handler.post {
                if (gatt != connection) return@post
                if (status == BluetoothGatt.GATT_SUCCESS && state == BluetoothProfile.STATE_CONNECTED) {
                    if (!gatt.discoverServices()) finish()
                } else if (state == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) finish()
            }
        }
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            handler.post {
                if (gatt != connection) return@post
                if (status != BluetoothGatt.GATT_SUCCESS) { finish(); return@post }
                // Only read standard Battery and Device Information services.
                for (service in gatt.services) {
                    if (service.uuid != uuid("180f") && service.uuid != uuid("180a")) continue
                    for (characteristic in service.characteristics) {
                        if (characteristic.uuid in listOf(batteryId, firmwareId, manufacturerId, modelId) &&
                            (characteristic.properties and BluetoothGattCharacteristic.PROPERTY_READ) != 0) queue.add(characteristic)
                    }
                }
                readNext()
            }
        }
        @Deprecated("Pre-Android 13 callback")
        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            if (Build.VERSION.SDK_INT < 33) {
                @Suppress("DEPRECATION")
                val value = characteristic.value ?: byteArrayOf()
                accept(gatt, characteristic.uuid, value, status)
            }
        }
        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
            accept(gatt, characteristic.uuid, value, status)
        }
    }

    private fun accept(gatt: BluetoothGatt, id: UUID, data: ByteArray, status: Int) {
        handler.post {
            if (gatt != connection || pendingRead == null) return@post
            if (status == BluetoothGatt.GATT_SUCCESS && data.isNotEmpty()) {
                when (id) {
                    batteryId -> { val level = data[0].toInt() and 255; if (level in 0..100) values["battery"] = level }
                    firmwareId -> values["firmware"] = data.toString(Charsets.UTF_8).trim('\u0000', ' ')
                    manufacturerId -> values["manufacturer"] = data.toString(Charsets.UTF_8).trim('\u0000', ' ')
                    modelId -> values["model"] = data.toString(Charsets.UTF_8).trim('\u0000', ' ')
                }
            }
            readNext()
        }
    }

    @Suppress("MissingPermission")
    private fun readNext() {
        val gatt = connection ?: return
        val next = queue.poll()
        if (next == null) { finish(); return }
        try { if (!gatt.readCharacteristic(next)) readNext() }
        catch (error: Exception) { finish() }
    }

    @Suppress("MissingPermission")
    private fun finish() {
        timeout?.let { handler.removeCallbacks(it) }
        timeout = null
        connection?.close()
        connection = null
        queue.clear()
        val result = pendingRead
        pendingRead = null
        result?.success(HashMap(values))
    }

    fun close() {
        pendingPermission?.error("CLOSED", "Tela encerrada.", null)
        pendingPermission = null
        finish()
    }
}
