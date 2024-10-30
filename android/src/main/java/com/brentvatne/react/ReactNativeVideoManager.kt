package com.brentvatne.react

import com.brentvatne.common.toolbox.DebugLog
import com.brentvatne.exoplayer.ReactExoplayerViewManager

/**
 * ReactNativeVideoManager is a singleton class which allows to manipulate / the global state of the app
 * It handles the list of <Video view instanced and registration of plugins
 */
class ReactNativeVideoManager : RNVPlugin {
    companion object {
        private const val TAG = "ReactNativeVideoManager"

        @Volatile
        private var instance: ReactNativeVideoManager? = null

        /**
         * Singleton accessor
         */
        fun getInstance(): ReactNativeVideoManager =
            instance ?: synchronized(this) {
                instance ?: ReactNativeVideoManager().also { instance = it }
            }
    }

    private var instanceList: ArrayList<ReactExoplayerViewManager> = ArrayList()
    private var pluginList: ArrayList<RNVPlugin> = ArrayList()

    /**
     * register a new ReactExoplayerViewManager in the managed list
     */
    fun registerView(newInstance: ReactExoplayerViewManager) {
        if (instanceList.size > 2) {
            DebugLog.d(TAG, "multiple Video displayed ?")
        }
        instanceList.add(newInstance)
    }

    /**
     * unregister existing ReactExoplayerViewManager in the managed list
     */
    fun unregisterView(newInstance: ReactExoplayerViewManager) {
        instanceList.remove(newInstance)
    }

    /**
     * register a new plugin in the managed list
     */
    fun registerPlugin(plugin: RNVPlugin) {
        pluginList.add(plugin)
        return
    }

    /**
     * unregister a plugin from the managed list
     */
    fun unregisterPlugin(plugin: RNVPlugin) {
        pluginList.remove(plugin)
        return
    }

    override fun onInstanceCreated(id: String, player: Any, playerView: Any) {
        pluginList.forEach { it.onInstanceCreated(id, player. playerView) }
    }

    override fun onInstanceRemoved(id: String, player: Any) {
        pluginList.forEach { it.onInstanceRemoved(id, player) }
    }
}
