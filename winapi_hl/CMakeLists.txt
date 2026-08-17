cmake_minimum_required(VERSION 3.10)
project(winapi_hdll)

set(HL_DIR $ENV{HASHLINK})

if(NOT HL_DIR)
    message(FATAL_ERROR "HASHLINK environment variable not found! Make sure it's set in your system.")
endif()

add_library(winapi SHARED winapi_hl.cpp)

target_include_directories(winapi PRIVATE "${HL_DIR}/include" "${HL_DIR}/src" "${HL_DIR}")

set_target_properties(winapi PROPERTIES PREFIX "")
set_target_properties(winapi PROPERTIES SUFFIX ".hdll")

target_link_directories(winapi PRIVATE "${HL_DIR}" "${HL_DIR}/lib")

target_link_libraries(winapi PRIVATE libhl Dwmapi ntdll User32 Shell32 gdi32)