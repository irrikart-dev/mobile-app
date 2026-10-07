package com.irrikart.app

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import java.io.File
import java.security.KeyStore

// razorpay_flutter's checkout UI needs a FragmentActivity host — plain
// FlutterActivity crashes it at runtime with a ClassCastException.
class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Must run before the Flutter engine starts: FirebaseAuth sets up its
        // storage crypto lazily, on the first Dart call into the plugin.
        clearUndecryptableFirebaseAuthState()
        super.onCreate(savedInstanceState)
    }

    /**
     * Firebase Auth encrypts its persisted session with a Tink keyset whose
     * master key lives in Android Keystore. Keystore keys are never part of a
     * device backup, so if Auto Backup ever restored the encrypted keyset
     * without its key, Firebase logs "Keystore cannot load the key" on every
     * launch, can neither read nor rewrite the session, and the user is signed
     * out on every restart. Deleting the orphaned keyset lets Firebase create a
     * fresh one on the next sign-in. Only files whose key is already gone are
     * touched — their contents are unrecoverable either way.
     */
    private fun clearUndecryptableFirebaseAuthState() {
        try {
            val prefsDir = File(applicationInfo.dataDir, "shared_prefs")
            val cryptoFiles = prefsDir.listFiles { f ->
                f.name.startsWith(CRYPTO_PREFIX) && f.name.endsWith(".xml")
            } ?: return
            if (cryptoFiles.isEmpty()) return

            val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            for (file in cryptoFiles) {
                val suffix = file.name.removePrefix(CRYPTO_PREFIX).removeSuffix(".xml")
                if (keyStore.containsAlias(KEY_ALIAS_PREFIX + suffix)) continue

                deleteSharedPreferences(CRYPTO_PREFIX + suffix)
                deleteSharedPreferences(STORE_PREFIX + suffix)
                Log.w(TAG, "Cleared Firebase Auth state with a missing Keystore key ($suffix)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Firebase Auth storage check failed", e)
        }
    }

    private companion object {
        const val TAG = "IrriKart"
        const val CRYPTO_PREFIX = "com.google.firebase.auth.api.crypto."
        const val STORE_PREFIX = "com.google.firebase.auth.api.Store."
        const val KEY_ALIAS_PREFIX = "firebear_main_key_id_for_storage_crypto."
    }
}
