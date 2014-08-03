include_directories("${PROJECT_SOURCE_DIR}")

set(SOURCE_FILES bsd_rand.c image_png.cpp intro.cpp main.cpp)

if (APPLE)
    list(APPEND SOURCE_FILES SDLMain.m)
endif (APPLE)

add_executable(whisky_in_a_tube ${SOURCE_FILES})
target_link_libraries(whisky_in_a_tube ${BOOST_LIBRARY})
target_link_libraries(whisky_in_a_tube ${GLEW_LIBRARY})
target_link_libraries(whisky_in_a_tube ${OPENGL_gl_LIBRARY})
target_link_libraries(whisky_in_a_tube ${PNG_LIBRARY})
target_link_libraries(whisky_in_a_tube ${SDL_LIBRARY})

