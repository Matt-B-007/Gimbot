cmake_minimum_required(VERSION 3.21)
project(gimbot VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(GNUInstallDirs)

option(BUILD_GUI "Build the desktop app (otherwise only gimbotctl)" ON)
option(WITH_KDE "Use KDE Frameworks for the tray, global shortcuts and crash reports when found" ON)
set(GIMBOT_MIN_QT 6.8 CACHE STRING "Oldest Qt 6 version to accept")
set(GIMBOT_REPO "" CACHE STRING "GitHub owner/repo, used for update checks and bug reports (e.g. alex/gimbot)")
set(OBSBOT_SDK_DIR "" CACHE PATH "Path to the extracted OBSBOT SDK (the folder containing include/ and linux/)")

# ---------------------------------------------------------------- OBSBOT SDK
# Without the SDK, Gimbot still builds with only the simulated camera. This is
# for automatic builds and contributors; a real install needs the SDK.
set(GIMBOT_HAVE_SDK OFF)
if(OBSBOT_SDK_DIR AND EXISTS "${OBSBOT_SDK_DIR}/include/dev/devs.hpp")
    set(GIMBOT_HAVE_SDK ON)
elseif(OBSBOT_SDK_DIR)
    message(FATAL_ERROR "OBSBOT_SDK_DIR=${OBSBOT_SDK_DIR} doesn't contain include/dev/devs.hpp")
else()
    message(WARNING "OBSBOT_SDK_DIR not set: building with the simulated camera only. "
                    "Pass -DOBSBOT_SDK_DIR=/path/to/libdev_v2.1.0_8 for real cameras.")
endif()

set(GIMBOT_SDK_VERSION "none")
if(GIMBOT_HAVE_SDK)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
        set(_sdk_arch arm64-release)
    else()
        set(_sdk_arch x86_64-release)
    endif()
    set(_sdk_libdir "${OBSBOT_SDK_DIR}/linux/${_sdk_arch}")

    # The zip ships copies instead of symlinks, and libdev.so is an older
    # build. Use the newest versioned file, whose SONAME matches its name.
    file(GLOB _sdk_libs "${_sdk_libdir}/libdev.so.*.*.*")
    if(NOT _sdk_libs)
        message(FATAL_ERROR "No libdev.so.X.Y.Z found in ${_sdk_libdir}")
    endif()
    list(SORT _sdk_libs COMPARE NATURAL ORDER DESCENDING)
    list(GET _sdk_libs 0 OBSBOT_SDK_LIB)
    get_filename_component(OBSBOT_SDK_LIB_NAME "${OBSBOT_SDK_LIB}" NAME)

    # The SDK version, from its folder name (libdev_v2.1.0_8 -> 2.1.0_8).
    get_filename_component(_sdk_folder "${OBSBOT_SDK_DIR}" NAME)
    string(REGEX REPLACE "^libdev_v?" "" GIMBOT_SDK_VERSION "${_sdk_folder}")
    message(STATUS "OBSBOT SDK ${GIMBOT_SDK_VERSION}: ${OBSBOT_SDK_LIB}")

    add_library(obsbot::dev SHARED IMPORTED)
    set_target_properties(obsbot::dev PROPERTIES
        IMPORTED_LOCATION "${OBSBOT_SDK_LIB}"
        IMPORTED_SONAME "${OBSBOT_SDK_LIB_NAME}"
        INTERFACE_INCLUDE_DIRECTORIES "${OBSBOT_SDK_DIR}/include")

    # The SDK is installed privately next to our binaries.
    set(GIMBOT_PRIVATE_LIBDIR "${CMAKE_INSTALL_LIBDIR}/gimbot")
    set(CMAKE_INSTALL_RPATH "$ORIGIN/../${GIMBOT_PRIVATE_LIBDIR}")
    set(CMAKE_BUILD_RPATH "${_sdk_libdir}")
    install(FILES "${OBSBOT_SDK_LIB}" DESTINATION "${GIMBOT_PRIVATE_LIBDIR}")
endif()

# ---------------------------------------------------------------- camera layer + gimbotctl
find_package(Qt6 ${GIMBOT_MIN_QT} REQUIRED COMPONENTS Core DBus)

add_library(gimbotcore STATIC
    src/core/camera.hpp src/core/camera.cpp
    src/core/fake_camera.cpp
    src/core/commands.hpp src/core/commands.cpp)
target_include_directories(gimbotcore PUBLIC src/core)
if(GIMBOT_HAVE_SDK)
    target_sources(gimbotcore PRIVATE src/core/sdk_camera.cpp)
    target_link_libraries(gimbotcore PUBLIC obsbot::dev)
else()
    target_sources(gimbotcore PRIVATE src/core/no_sdk.cpp)
endif()
target_compile_options(gimbotcore PRIVATE -Wall -Wextra -Wno-unused-parameter)

add_executable(gimbotctl src/cli/main.cpp)
target_link_libraries(gimbotctl PRIVATE gimbotcore Qt6::Core Qt6::DBus)
install(TARGETS gimbotctl RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(FILES data/60-obsbot.rules DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/udev/rules.d)

# ---------------------------------------------------------------- desktop app
if(BUILD_GUI)
    find_package(Qt6 ${GIMBOT_MIN_QT} REQUIRED COMPONENTS Gui Widgets Network Svg Qml Quick QuickControls2 Multimedia)
    qt_standard_project_setup()

    set(GIMBOT_HAVE_KF6 OFF)
    if(WITH_KDE)
        find_package(ECM 6.0 QUIET NO_MODULE)
        find_package(KF6 6.0 QUIET COMPONENTS CoreAddons Crash GlobalAccel StatusNotifierItem)
        if(KF6CoreAddons_FOUND AND KF6Crash_FOUND AND KF6GlobalAccel_FOUND AND KF6StatusNotifierItem_FOUND)
            set(GIMBOT_HAVE_KF6 ON)
        endif()
    endif()
    message(STATUS "KDE Frameworks integration: ${GIMBOT_HAVE_KF6}")

    qt_add_executable(gimbot
        src/app/main.cpp
        src/app/controller.cpp src/app/controller.hpp
        src/app/worker.cpp src/app/worker.hpp
        src/app/logger.cpp src/app/logger.hpp
        src/app/updater.cpp src/app/updater.hpp
        src/app/platform.cpp src/app/platform.hpp)

    set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
    # Place every QML file and asset at the module's root (not under qml/),
    # so files in the module see Theme as the shared singleton.
    file(GLOB _gimbot_qml_assets RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
         qml/*.qml qml/icons/* qml/fonts/*.ttf)
    foreach(_f IN LISTS _gimbot_qml_assets)
        string(REGEX REPLACE "^qml/" "" _alias "${_f}")
        set_source_files_properties(${_f} PROPERTIES QT_RESOURCE_ALIAS "${_alias}")
    endforeach()
    qt_add_qml_module(gimbot
        URI Gimbot
        VERSION 1.0
        RESOURCE_PREFIX /qt/qml
        QML_FILES
            qml/Main.qml qml/Theme.qml
            qml/StudioPage.qml qml/SettingsPage.qml qml/ConnectPage.qml
            qml/TopBar.qml qml/Preview.qml qml/PresetStrip.qml
            qml/AimCard.qml qml/TrackingCard.qml qml/ImageCard.qml qml/Banner.qml
            qml/CommandPalette.qml qml/ReportDialog.qml qml/AboutDialog.qml
            qml/NameDialog.qml qml/ConfirmDialog.qml qml/Sheet.qml qml/Toasts.qml
            qml/Icon.qml qml/Btn.qml qml/IconBtn.qml qml/Segmented.qml qml/Toggle.qml
            qml/SliderRow.qml qml/Select.qml qml/Card.qml qml/SettingRow.qml qml/Field.qml
            qml/Kbd.qml qml/StyledMenu.qml qml/AbstractButtonLike.qml
        RESOURCES
            qml/icons/gimbot.svg
            qml/fonts/Inter-Regular.ttf qml/fonts/Inter-Medium.ttf
            qml/fonts/Inter-SemiBold.ttf qml/fonts/Inter-Bold.ttf)

    target_link_libraries(gimbot PRIVATE gimbotcore
        Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Network Qt6::DBus
        Qt6::Svg Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Multimedia)
    target_compile_definitions(gimbot PRIVATE
        GIMBOT_VERSION="${PROJECT_VERSION}"
        GIMBOT_SDK_VERSION="${GIMBOT_SDK_VERSION}"
        GIMBOT_REPO="${GIMBOT_REPO}")
    target_compile_options(gimbot PRIVATE -Wall -Wextra -Wno-unused-parameter)
    if(GIMBOT_HAVE_KF6)
        target_link_libraries(gimbot PRIVATE KF6::CoreAddons KF6::Crash KF6::GlobalAccel KF6::StatusNotifierItem)
        target_compile_definitions(gimbot PRIVATE GIMBOT_HAVE_KF6)
    endif()

    install(TARGETS gimbot RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(FILES data/io.github.gimbot.Gimbot.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
    install(FILES data/io.github.gimbot.Gimbot.metainfo.xml DESTINATION ${CMAKE_INSTALL_DATADIR}/metainfo)
    install(FILES data/icons/gimbot.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
    install(FILES data/icons/gimbot-symbolic.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/symbolic/apps)
    install(DIRECTORY data/icons/hicolor/ DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor)
    install(FILES data/io.github.gimbot.Gimbot.service DESTINATION ${CMAKE_INSTALL_DATADIR}/dbus-1/services)
endif()

# ---------------------------------------------------------------- tests
include(CTest)
if(BUILD_TESTING)
    find_package(Qt6 ${GIMBOT_MIN_QT} REQUIRED COMPONENTS Test)
    add_executable(gimbot_tests tests/test_core.cpp src/app/updater.cpp)
    target_include_directories(gimbot_tests PRIVATE src/app)
    target_link_libraries(gimbot_tests PRIVATE gimbotcore Qt6::Core Qt6::Network Qt6::Test)
    add_test(NAME gimbot_tests COMMAND gimbot_tests)
endif()
