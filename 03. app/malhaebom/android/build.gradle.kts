// android/build.gradle.kts
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/**
 * Flutter 기본 템플릿: android 모듈의 빌드 산출물을
 * 프로젝트 루트(…/brain_up) 아래의 build/에 모읍니다.
 * 절대경로는 쓰지 않습니다.
 */
buildDir = File("../build")

subprojects {
    // 각 서브프로젝트의 빌드 디렉터리도 루트 build/ 아래로 정리
    project.buildDir = File(rootProject.buildDir, project.name)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}