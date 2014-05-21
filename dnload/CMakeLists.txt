cmake_minimum_required(VERSION 2.6)

project(stub)

enable_language(C)
enable_language(CXX)

include("defaults.cmake")

find_boost(TRUE program_options)
find_glew(TRUE STATIC)
find_png(TRUE)
find_sdl(TRUE)

add_definitions(-DUSE_LD)

output_flags("DEBUG" on)

add_subdirectory(src)
