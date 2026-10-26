cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "fplayer")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "fplayer_plugin")

set(IJKPLAYER_ROOT ""
    CACHE PATH "Directory containing fplayercore.lib, fplayercore.dll and fplayercore.h")

if(NOT IJKPLAYER_ROOT)
  if(DEFINED ENV{IJKPLAYER_ROOT} AND NOT "$ENV{IJKPLAYER_ROOT}" STREQUAL "")
    set(IJKPLAYER_ROOT "$ENV{IJKPLAYER_ROOT}"
        CACHE PATH "Directory containing fplayercore.lib, fplayercore.dll and fplayercore.h" FORCE)
  else()
    get_filename_component(FPLAYER_PLUGIN_REAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
    set(IJKPLAYER_ROOT "${FPLAYER_PLUGIN_REAL_DIR}/windows/third_party/fplayercore"
        CACHE PATH "Directory containing fplayercore.lib, fplayercore.dll and fplayercore.h" FORCE)
  endif()
endif()
set(IJKPLAYER_INCLUDE_DIR "${IJKPLAYER_ROOT}/include")
set(IJKPLAYER_LIB_DIR "${IJKPLAYER_ROOT}/lib")
set(IJKPLAYER_DLL "${IJKPLAYER_ROOT}/bin/fplayercore.dll")

if(NOT EXISTS "${IJKPLAYER_LIB_DIR}/fplayercore.lib")
  message(FATAL_ERROR
    "fplayercore.lib not found in ${IJKPLAYER_LIB_DIR}. Build ijkplayer for Windows first "
    "(scripts/windows/prepare-deps.ps1 then scripts/windows/build-windows.ps1), "
    "or pass -DIJKPLAYER_ROOT=<build output> / set the IJKPLAYER_ROOT environment variable.")
endif()

list(APPEND PLUGIN_SOURCES
  "fplayer_plugin.cpp"
  "fplayer_plugin.h"
  "fplayer_plugin_c_api.cpp"
  "fplayer.cpp"
  "fplayer.h"
  "fplayer_protocol.h"
  "png_writer.cpp"
  "png_writer.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/fplayer/fplayer_plugin.h"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${IJKPLAYER_INCLUDE_DIR}"
)
target_link_directories(${PLUGIN_NAME} PRIVATE "${IJKPLAYER_LIB_DIR}")
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  fplayercore
  windowscodecs
  ole32
)

set(FPLAYER_BUNDLED_DLLS "")
if(EXISTS "${IJKPLAYER_DLL}")
  list(APPEND FPLAYER_BUNDLED_DLLS "${IJKPLAYER_DLL}")
endif()

if(DEFINED VCPKG_INSTALLED_DIR AND DEFINED VCPKG_TARGET_TRIPLET)
  file(GLOB FPLAYER_VCPKG_DLLS
    "${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/bin/*.dll")
  list(APPEND FPLAYER_BUNDLED_DLLS ${FPLAYER_VCPKG_DLLS})
endif()

set(fplayer_bundled_libraries ${FPLAYER_BUNDLED_DLLS} PARENT_SCOPE)
