###############################################################################
#C++ compilation
add_constant_table("${CMAKE_SOURCE_DIR}/rtl/achd-soc/noc/dma/DMARouter.constants")
include_directories(${CMAKE_CURRENT_BINARY_DIR})
add_executable(scoped
	main.cpp
	${CMAKE_CURRENT_BINARY_DIR}/DMARouter_constants.h
)

add_dependencies(scoped svnversion)

###############################################################################
#Linker settings
target_link_libraries(scoped
	m rt jtaghal pthread scopehal
)

