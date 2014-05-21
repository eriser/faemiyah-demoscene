include_directories("${PROJECT_SOURCE_DIR}")

add_executable(stub bsd_rand.c image_png.cpp intro.cpp main.cpp)
target_link_libraries(stub ${BOOST_LIBRARY})
target_link_libraries(stub ${GLEW_LIBRARY})
target_link_libraries(stub ${PNG_LIBRARY})
target_link_libraries(stub ${SDL_LIBRARY})
