package com.melihhakanpektas.flutter_midi_pro

import android.os.Debug
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/** FlutterMidiProPlugin */
class FlutterMidiProPlugin: FlutterPlugin, MethodCallHandler {
  companion object {
    private const val TAG = "FlutterMidiPro"
    // Diagnostic toggle: set to false to test plugin registration without native loading.
    private const val AUTO_LOAD_NATIVE_LIBRARY = false
    private var nativeLibraryLoaded = false

    init {
      Log.i(TAG, "plugin class init")
      if (AUTO_LOAD_NATIVE_LIBRARY) {
        loadNativeLibrary()
      } else {
        Log.w(TAG, "native-lib auto-load disabled by diagnostic toggle")
      }
    }

    @JvmStatic
    @Synchronized
    private fun loadNativeLibrary() {
      if (nativeLibraryLoaded) {
        Log.i(TAG, "System.loadLibrary(native-lib) skipped; already loaded")
        return
      }
      Log.i(TAG, "before System.loadLibrary(native-lib)")
      System.loadLibrary("native-lib")
      nativeLibraryLoaded = true
      Log.i(TAG, "after System.loadLibrary(native-lib)")
    }

    @JvmStatic
    private external fun nativePing(): String

    @JvmStatic
    private external fun fluidsynthInit()

    @JvmStatic
    private external fun loadSoundfont(path: String, resetPresets: Boolean): Int

    @JvmStatic
    private external fun selectInstrument(sfId: Int, channel:Int, bank: Int, program: Int)

    @JvmStatic
    private external fun playNote(channel: Int, key: Int, velocity: Int)

    @JvmStatic
    private external fun stopNote(channel: Int, key: Int)

    @JvmStatic
    private external fun listBanksAndPrograms(sfId: Int): HashMap<Int, HashMap<Int, String>>?

    @JvmStatic
    private external fun unloadSoundfont(sfId: Int, resetPresets: Boolean = false)
    @JvmStatic
    private external fun dispose()
  }

  private lateinit var channel : MethodChannel
  private var fluidsynthReady = false

  private fun logMemory(label: String) {
    val runtime = Runtime.getRuntime()
    val nativeHeap = Debug.getNativeHeapAllocatedSize() / 1024
    val javaUsed = (runtime.totalMemory() - runtime.freeMemory()) / 1024
    val javaTotal = runtime.totalMemory() / 1024
    Log.i(
      TAG,
      "memory [$label]: nativeHeap=${nativeHeap}KB javaUsed=${javaUsed}KB javaTotal=${javaTotal}KB",
    )
  }

  @Synchronized
  private fun ensureFluidsynthReady() {
    if (fluidsynthReady) {
      return
    }
    loadNativeLibrary()
    logMemory("before fluidsynthInit")
    fluidsynthInit()
    fluidsynthReady = true
    logMemory("after fluidsynthInit")
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    Log.i(TAG, "onAttachedToEngine start")
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_midi_pro")
    channel.setMethodCallHandler(this)
    logMemory("attached to engine")
    Log.i(TAG, "onAttachedToEngine complete")
  }
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "ping" -> {
        Log.i(TAG, "ping")
        result.success("pong")
      }
      "loadNativeLibrary" -> {
        Log.i(TAG, "loadNativeLibrary call")
        try {
          loadNativeLibrary()
          result.success(null)
        } catch (error: Throwable) {
          Log.e(TAG, "loadNativeLibrary failed", error)
          result.error("NATIVE_LOAD_FAILED", error.message, null)
        }
      }
      "nativePing" -> {
        Log.i(TAG, "nativePing call")
        try {
          loadNativeLibrary()
          val response = nativePing()
          Log.i(TAG, "nativePing result=$response")
          result.success(response)
        } catch (error: Throwable) {
          Log.e(TAG, "nativePing failed", error)
          result.error("NATIVE_PING_FAILED", error.message, null)
        }
      }
      "fluidsynthInit" -> {
        Log.i(TAG, "fluidsynthInit call")
        try {
          ensureFluidsynthReady()
          result.success(null)
        } catch (error: Throwable) {
          Log.e(TAG, "fluidsynthInit failed", error)
          result.error("FLUIDSYNTH_INIT_FAILED", error.message, null)
        }
      }
      "loadSoundfont" -> {
        val path = call.argument<String>("path")
        val resetPresets = call.argument<Boolean>("resetPresets") ?: false
        if (path != null) {
          Log.i(TAG, "loadSoundfont call path=$path resetPresets=$resetPresets")
          try {
            ensureFluidsynthReady()
            logMemory("before loadSoundfont path=$path")
            val sfId = loadSoundfont(path, resetPresets)
            logMemory("after loadSoundfont sfId=$sfId")
            if (sfId == -1) {
              result.error("INVALID_ARGUMENT", "Something went wrong. Check the path of the template soundfont", null)
            } else {
              result.success(sfId)
            }
          } catch (error: Throwable) {
            Log.e(TAG, "loadSoundfont failed", error)
            result.error("LOAD_SOUNDFONT_FAILED", error.message, null)
          }
        } else {
            result.error("INVALID_ARGUMENT", "Path is required", null)
        }
      }
      "selectInstrument" -> {
        val sfId = call.argument<Int>("sfId")?:0
        val channel = call.argument<Int>("channel")?:0
        val bank = call.argument<Int>("bank")?:0
        val program = call.argument<Int>("program")?:0
          ensureFluidsynthReady()
          logMemory("before selectInstrument sfId=$sfId channel=$channel bank=$bank program=$program")
          selectInstrument(sfId, channel, bank, program)
          logMemory("after selectInstrument sfId=$sfId channel=$channel")
          result.success(null)
        }
      "playNote" -> {
        val channel = call.argument<Int>("channel")
        val key = call.argument<Int>("key")
        val velocity = call.argument<Int>("velocity")
        if (channel != null && key != null && velocity != null) {
          ensureFluidsynthReady()
          playNote(channel, key, velocity)
          result.success(null)
        } else {
          result.error("INVALID_ARGUMENT", "channel, key, and velocity are required", null)
        }
      }
      "stopNote" -> {
        val channel = call.argument<Int>("channel")
        val key = call.argument<Int>("key")
        if (channel != null && key != null) {
          ensureFluidsynthReady()
          stopNote(channel, key)
          result.success(null)
        } else {
          result.error("INVALID_ARGUMENT", "channel and key are required", null)
        }
      }
      "unloadSoundfont" -> {
        val sfId = call.argument<Int>("sfId")
        val resetPresets = call.argument<Boolean>("resetPresets") ?: false
        if (sfId != null) {
          ensureFluidsynthReady()
          logMemory("before unloadSoundfont sfId=$sfId")
          unloadSoundfont(sfId, resetPresets)
          logMemory("after unloadSoundfont sfId=$sfId")
          result.success(null)
        } else {
          result.error("INVALID_ARGUMENT", "sfId is required", null)
        }
      }
      "dispose" -> {
        logMemory("before dispose")
        if (fluidsynthReady) {
          dispose()
          fluidsynthReady = false
        }
        logMemory("after dispose")
        result.success(null)
      }
     "listBanksAndPrograms" -> {
                val sfId = call.argument<Int>("sfId") ?: 0
                ensureFluidsynthReady()
                logMemory("before listBanksAndPrograms sfId=$sfId")
                val mapOfPrograms = listBanksAndPrograms(sfId)
                logMemory("after listBanksAndPrograms sfId=$sfId")
                val banksAndPrograms = mapOfPrograms?.mapValues { it.value.toMap() }
                if (banksAndPrograms != null) {
                    result.success(banksAndPrograms)
                } else {
                    result.error("INVALID_ARGUMENT", "Could not retrieve banks and programs", null)
                }
            }
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
