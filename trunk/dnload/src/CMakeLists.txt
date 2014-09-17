include_directories("${PROJECT_SOURCE_DIR}")

add_executable(intro bsd_rand.c glsl_shader_source.cpp image_png.cpp intro.cpp main.cpp)
target_link_libraries(intro ${BOOST_PROGRAM_OPTIONS_LIBRARY})
target_link_libraries(intro ${GLEW_LIBRARY})
target_link_libraries(intro ${PNG_LIBRARY})
target_link_libraries(intro ${SDL_LIBRARY})
