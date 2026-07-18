#include <jni.h>
#include <fluidsynth.h>
#include <android/log.h>
#include <unistd.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <stdexcept>
#include <string>

// Global FluidSynth synthesizer instance
fluid_synth_t* synth = NULL;
std::map<int, int> soundfonts;
fluid_audio_driver_t* driver = NULL;
fluid_settings_t* settings = NULL;
bool isInitialized = false;

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    __android_log_print(ANDROID_LOG_INFO, "FlutterMidiProNative", "JNI_OnLoad native-lib loaded");
    return JNI_VERSION_1_6;
}

static void log_memory(const char* label) {
    long rssKb = -1;
    long vmSizeKb = -1;
    FILE* status = fopen("/proc/self/status", "r");
    if (status != nullptr) {
        char line[256];
        while (fgets(line, sizeof(line), status) != nullptr) {
            if (strncmp(line, "VmRSS:", 6) == 0) {
                rssKb = strtol(line + 6, nullptr, 10);
            } else if (strncmp(line, "VmSize:", 7) == 0) {
                vmSizeKb = strtol(line + 7, nullptr, 10);
            }
        }
        fclose(status);
    }
    __android_log_print(
        ANDROID_LOG_INFO,
        "FlutterMidiProNative",
        "memory [%s]: VmRSS=%ldKB VmSize=%ldKB soundfonts=%zu initialized=%d",
        label,
        rssKb,
        vmSizeKb,
        soundfonts.size(),
        isInitialized ? 1 : 0
    );
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_nativePing(JNIEnv* env, jclass clazz) {
    __android_log_print(ANDROID_LOG_INFO, "FlutterMidiProNative", "nativePing");
    return env->NewStringUTF("native pong");
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_fluidsynthInit(JNIEnv* env,jclass clazz) {
    __android_log_print(ANDROID_LOG_INFO, "FlutterMidiProNative", "fluidsynthInit");
    log_memory("before fluidsynthInit");
    if (isInitialized) {
        throw std::runtime_error("FluidSynth is already initialized");
    } else {
        settings = new_fluid_settings();
        fluid_settings_setint(settings, "synth.dynamic-sample-loading", 1);
        synth = new_fluid_synth(settings);
        driver = new_fluid_audio_driver(settings, synth);
        isInitialized = true;
    }
    log_memory("after fluidsynthInit");
}

extern "C" JNIEXPORT int JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_loadSoundfont(JNIEnv* env, jclass clazz, jstring path, jboolean resetPresets) {
    const char *nativePath = env->GetStringUTFChars(path, nullptr);
    __android_log_print(ANDROID_LOG_INFO, "FlutterMidiProNative", "loadSoundfont path=%s resetPresets=%d", nativePath, resetPresets ? 1 : 0);
    log_memory("before fluid_synth_sfload");
    int sfId = fluid_synth_sfload(synth, nativePath, resetPresets);
    log_memory("after fluid_synth_sfload");
    env->ReleaseStringUTFChars(path, nativePath);
    if (sfId != -1) {
        soundfonts[sfId] = sfId;
    }
    log_memory("after loadSoundfont map update");
    return sfId;
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_selectInstrument(JNIEnv* env, jclass clazz, jint sfId, jint channel, jint bank, jint program) {
    __android_log_print(ANDROID_LOG_INFO, "FlutterMidiProNative", "selectInstrument sfId=%d channel=%d bank=%d program=%d", sfId, channel, bank, program);
    log_memory("before fluid_synth_program_select");
    fluid_synth_program_select(synth, channel, soundfonts[sfId], bank, program);
    log_memory("after fluid_synth_program_select");
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_playNote(JNIEnv* env, jclass clazz, jint channel, jint key, jint velocity) {
    fluid_synth_noteon(synth, channel, key, velocity);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_stopNote(JNIEnv* env, jclass clazz, jint channel, jint key) {
    fluid_synth_noteoff(synth, channel, key);
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_unloadSoundfont(JNIEnv* env, jclass clazz, jint sfId, jboolean resetPresets) {
    log_memory("before fluid_synth_sfunload");
    fluid_synth_sfunload(synth, soundfonts[sfId], resetPresets);
    soundfonts.erase(sfId);
    log_memory("after fluid_synth_sfunload");
}

extern "C" JNIEXPORT void JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_dispose(JNIEnv* env, jclass clazz) {
    log_memory("before dispose");
    delete_fluid_audio_driver(driver);
    delete_fluid_synth(synth);
    delete_fluid_settings(settings);
    synth = NULL;
    driver = NULL;
    settings = NULL;
    soundfonts.clear();
    isInitialized = false;
    log_memory("after dispose");
}

extern "C" JNIEXPORT jobject JNICALL
Java_com_melihhakanpektas_flutter_1midi_1pro_FlutterMidiProPlugin_listBanksAndPrograms(JNIEnv* env, jclass clazz, jint sfId) {
    log_memory("before listBanksAndPrograms");
    fluid_sfont_t* sfont = fluid_synth_get_sfont_by_id(synth, sfId);
    if (!sfont) {
        return NULL;
    }

    std::map<int, std::map<int, std::string>> bankProgramMap;
    fluid_preset_t* preset = NULL;
    fluid_sfont_iteration_start(sfont);
    while ((preset = fluid_sfont_iteration_next(sfont)) != NULL) {
        int bankNum = fluid_preset_get_banknum(preset);
        int programNum = fluid_preset_get_num(preset);
        std::string programName = fluid_preset_get_name(preset);
        bankProgramMap[bankNum][programNum] = programName;
    }

    jclass mapClass = env->FindClass("java/util/HashMap");
    jmethodID mapConstructor = env->GetMethodID(mapClass, "<init>", "()V");
    jmethodID mapPut = env->GetMethodID(mapClass, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

    jobject outerMap = env->NewObject(mapClass, mapConstructor);

    for (const auto& bankEntry : bankProgramMap) {
        jobject innerMap = env->NewObject(mapClass, mapConstructor);
        for (const auto& programEntry : bankEntry.second) {
            jint programNum = programEntry.first;
            jstring programName = env->NewStringUTF(programEntry.second.c_str());
            env->CallObjectMethod(innerMap, mapPut, env->NewObject(env->FindClass("java/lang/Integer"), env->GetMethodID(env->FindClass("java/lang/Integer"), "<init>", "(I)V"), programNum), programName);
            env->DeleteLocalRef(programName);
        }
        env->CallObjectMethod(outerMap, mapPut, env->NewObject(env->FindClass("java/lang/Integer"), env->GetMethodID(env->FindClass("java/lang/Integer"), "<init>", "(I)V"), bankEntry.first), innerMap);
        env->DeleteLocalRef(innerMap);
    }

    log_memory("after listBanksAndPrograms");
    return outerMap;
}
