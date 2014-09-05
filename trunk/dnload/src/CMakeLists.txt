include_directories("${PROJECT_SOURCE_DIR}")

add_executable(stub bsd_rand.c glsl_shader_source.cpp image_png.cpp intro.cpp main.cpp)
target_link_libraries(stub ${BOOST_PROGRAM_OPTIONS_LIBRARY})
target_link_libraries(stub ${GLEW_LIBRARY})
target_link_libraries(stub ${PNG_LIBRARY})
target_link_libraries(stub ${SDL_LIBRARY})
