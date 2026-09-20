import java.io.FileInputStream
import java.net.URI
import java.util.Base64
import java.util.Properties

fun decodeDartDefines(raw: String?): Map<String, String> = raw
    .orEmpty()
    .split(',')
    .filter(String::isNotBlank)
    .mapNotNull { encoded ->
        runCatching {
            String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
        }.getOrNull()
    }
    .mapNotNull { entry ->
        val separator = entry.indexOf('=')
        if (separator <= 0) null else entry.substring(0, separator) to entry.substring(separator + 1)
    }
    .toMap()

fun httpsUri(variable: String, value: String): URI {
    val uri = runCatching { URI(value) }.getOrNull()
        ?: throw GradleException("$variable deve ser uma URL HTTPS valida.")
    if (
        uri.scheme != "https" ||
        uri.host.isNullOrBlank() ||
        uri.userInfo != null ||
        uri.query != null ||
        uri.fragment != null
    ) {
        throw GradleException("$variable deve ser uma URL HTTPS valida.")
    }
    return uri.normalize()
}

fun validateDebugStagingDefines(defines: Map<String, String>) {
    if (defines["TUTOR_ENVIRONMENT"] != "staging") {
        throw GradleException(
            "Build debug bloqueado: defina TUTOR_ENVIRONMENT=staging via --dart-define-from-file.",
        )
    }

    val apiUri = httpsUri("TUTOR_API_URL", defines["TUTOR_API_URL"].orEmpty())
    val allowedApiUri = httpsUri(
        "TUTOR_STAGING_API_URL",
        defines["TUTOR_STAGING_API_URL"].orEmpty(),
    )
    val approvedApiUri = URI(
        "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api",
    ).normalize()
    if (
        apiUri != allowedApiUri ||
        apiUri != approvedApiUri
    ) {
        throw GradleException(
            "Build debug bloqueado: TUTOR_API_URL deve ser a rota de staging aprovada.",
        )
    }

    val gatewayUrl = defines["TUTOR_GATEWAY_URL"].orEmpty()
    if (gatewayUrl.isNotBlank()) {
        val gatewayUri = httpsUri("TUTOR_GATEWAY_URL", gatewayUrl)
        val allowedGatewayUri = httpsUri(
            "TUTOR_STAGING_GATEWAY_URL",
            defines["TUTOR_STAGING_GATEWAY_URL"].orEmpty(),
        )
        if (
            gatewayUri != allowedGatewayUri ||
            !gatewayUri.path.lowercase().contains("staging")
        ) {
            throw GradleException(
                "Build debug bloqueado: gateway deve ser de staging ou ficar vazio.",
            )
        }
    }
}

fun validateReleaseProductionDefines(defines: Map<String, String>) {
    if (defines["TUTOR_ENVIRONMENT"] != "production") {
        throw GradleException(
            "Build release bloqueado: TUTOR_ENVIRONMENT deve ser production.",
        )
    }

    val approvedValues = mapOf(
        "TUTOR_API_URL" to "https://ead.ipexdesenvolvimento.cloud/tutor-api",
        "TUTOR_GATEWAY_URL" to "https://tutor-tds-gateway.tdsipex.workers.dev",
        "PRIVACY_POLICY_URL" to "https://cartilhas.ipexdesenvolvimento.cloud/privacy.html",
        "ACCOUNT_DELETION_URL" to "https://cartilhas.ipexdesenvolvimento.cloud/account-deletion.html",
    )
    approvedValues.forEach { (variable, approvedValue) ->
        val actual = httpsUri(variable, defines[variable].orEmpty())
        val approved = URI(approvedValue).normalize()
        if (actual != approved) {
            throw GradleException(
                "Build release bloqueado: $variable deve usar o endpoint de producao aprovado.",
            )
        }
        if (
            actual.host.lowercase().contains("staging") ||
            actual.path.lowercase().contains("staging")
        ) {
            throw GradleException(
                "Build release bloqueado: $variable nao pode apontar para staging.",
            )
        }
    }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tutortds_cartilhas"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.tutortds_cartilhas"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            // Permite testes USB lado a lado com a versão instalada pela Play.
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        release {
            // Sem key.properties o bundle de validação é gerado sem assinatura local.
            // Nunca reutilize a chave de debug em uma versão da Play Store.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Qualquer build/execucao debug passa por este gate, inclusive via Android Studio.
tasks.matching { it.name == "preDebugBuild" }.configureEach {
    doFirst {
        validateDebugStagingDefines(
            decodeDartDefines(project.findProperty("dart-defines")?.toString()),
        )
    }
}

// Um bundle da Play nunca pode ser gerado sem configuração produtiva explícita
// nem herdar a rota isolada usada no APK DEV.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        validateReleaseProductionDefines(
            decodeDartDefines(project.findProperty("dart-defines")?.toString()),
        )
    }
}
