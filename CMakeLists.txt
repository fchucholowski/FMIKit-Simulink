cmake_minimum_required (VERSION 3.16)

set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING INTERNAL FORCE)

set (CMAKE_CXX_STANDARD 11)

project (FMIKit)

if (MSVC)
  # link statically against the the Visual C runtime
  string(REPLACE "/MD"  "/MT"  CMAKE_C_FLAGS_RELEASE   "${CMAKE_C_FLAGS_RELEASE}")
  string(REPLACE "/MD"  "/MT"  CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}")
  string(REPLACE "/MDd" "/MTd" CMAKE_C_FLAGS_DEBUG     "${CMAKE_C_FLAGS_DEBUG}")
  string(REPLACE "/MDd" "/MTd" CMAKE_CXX_FLAGS_DEBUG   "${CMAKE_CXX_FLAGS_DEBUG}")
endif ()

find_package(Matlab)
set(MATLAB_DIR ${Matlab_ROOT_DIR})
set(TARGET_SUFFIX ${Matlab_MEX_EXTENSION})
link_directories(${Matlab_MX_LIBRARY}/../)

add_library(sfun_fmurun SHARED
  include/fmi1.h
  include/fmi2Functions.h
  include/fmi2FunctionTypes.h
  include/fmi2TypesPlatform.h
  include/FMU.h
  include/FMU1.h
  include/FMU2.h
  sfun_fmurun.cpp
  src/FMU.cpp
  src/FMU1.cpp
  src/FMU2.cpp
)

SET_TARGET_PROPERTIES(sfun_fmurun PROPERTIES PREFIX "")


if (WIN32)
  target_compile_definitions(sfun_fmurun PUBLIC
    MATLAB_MEX_FILE
    _CRT_SECURE_NO_WARNINGS
    "DLL_EXPORT_SYM=__declspec(dllexport)"
  )
else ()
  target_compile_definitions(sfun_fmurun PUBLIC MATLAB_MEX_FILE)
endif ()

target_include_directories(sfun_fmurun PUBLIC
	${MATLAB_DIR}/extern/include
	${MATLAB_DIR}/simulink/include
	include
	coder
)

if (WIN32)
  target_link_libraries(sfun_fmurun libmat libmex libmx shlwapi)
elseif (APPLE)
  target_link_libraries(sfun_fmurun
    ${MATLAB_DIR}/bin/maci64/libmat.dylib
    ${MATLAB_DIR}/bin/maci64/libmex.dylib
    ${MATLAB_DIR}/bin/maci64/libmx.dylib
  )
endif ()

set_target_properties(sfun_fmurun PROPERTIES SUFFIX ".${TARGET_SUFFIX}")

add_custom_command(TARGET sfun_fmurun POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy
  "$<TARGET_FILE:sfun_fmurun>"
  "${CMAKE_CURRENT_SOURCE_DIR}"
)
