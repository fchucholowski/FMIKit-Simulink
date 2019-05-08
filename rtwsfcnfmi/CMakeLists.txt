cmake_minimum_required (VERSION 3.2)

set(MODEL_NAME "BouncingBall" CACHE STRING "Model name")
set(SOLVER "ode1" CACHE STRING "Solver")
set_property(CACHE SOLVER PROPERTY STRINGS ode1 ode2 ode3 ode4 ode5 ode8 ode14x)
set(MATLAB_ROOT "C:/Program Files/MATLAB/R2019a" CACHE STRING "MATLAB install directory")
set(RTW_DIR "E:/Development/FMIKit-Simulink/BouncingBall_sfcn_rtw_fmi" CACHE STRING "RTW generated model directory")
set(FMU_BUILD_DIR "${RTW_DIR}/FMUArchive")

project (${MODEL_NAME})

if (WIN32)
  set(FMI_PLATFORM win)
elseif (APPLE)
  set(FMI_PLATFORM darwin)
else ()
  set(FMI_PLATFORM linux)
endif ()

if ("${CMAKE_SIZEOF_VOID_P}" STREQUAL "8")
  set (FMI_PLATFORM ${FMI_PLATFORM}64)
else ()
  set (FMI_PLATFORM ${FMI_PLATFORM}32)
endif ()

set(SOLVER_SOURCES "${MATLAB_ROOT}/rtw/c/src/${SOLVER}.c")

if ("${SOLVER}" STREQUAL "ode14x")
  set(SOLVER_SOURCES
    ${SOLVER_SOURCES}
    "${MATLAB_ROOT}/rtw/c/src/matrixmath/rt_backsubrr_dbl.c"
    "${MATLAB_ROOT}/rtw/c/src/matrixmath/rt_forwardsubrr_dbl.c"
    "${MATLAB_ROOT}/rtw/c/src/matrixmath/rt_lu_real.c"
  )
endif ()

add_library(${SOLVER} STATIC ${SOLVER_SOURCES})

target_compile_definitions(${SOLVER} PRIVATE
	_CRT_SECURE_NO_WARNINGS
	NRT
	RT_MALLOC
)

target_include_directories(${SOLVER} PRIVATE
  "${RTW_DIR}"
  "${MATLAB_ROOT}/extern/include"
  "${MATLAB_ROOT}/simulink/include"
  "${MATLAB_ROOT}/rtw/c/src/matrixmath"
  "${MATLAB_ROOT}/rtw/c/src"
)

add_library(${MODEL_NAME}_sf SHARED
  "c/fmi.h"
  "c/fmi/fmi2Functions.h"
  "c/fmi/fmi2FunctionTypes.h"
  "c/fmi/fmi2TypesPlatform.h"
  "c/fmi2Functions.c"
  "c/fmi2.c"
  "${RTW_DIR}/${MODEL_NAME}_sf_data.c"
  "${RTW_DIR}/rtGetInf.c"
  "${RTW_DIR}/rtGetNaN.c"
  "${RTW_DIR}/modelDescription.xml"
)

target_link_libraries(${MODEL_NAME}_sf
  "${MATLAB_ROOT}/extern/lib/win64/microsoft/libmx.lib"
  "${MATLAB_ROOT}/extern/lib/win64/microsoft/libmex.lib"
  "${MATLAB_ROOT}/extern/lib/win64/microsoft/sf_runtime.lib"
  ${SOLVER}
)

target_compile_definitions(${MODEL_NAME}_sf PRIVATE
	_CRT_SECURE_NO_WARNINGS
	FIPXT_SHARED_MODULE
	rt_matrx_h
	RT_MALLOC
	NDEBUG
)

target_include_directories(${MODEL_NAME}_sf PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${RTW_DIR}"
  "${MATLAB_ROOT}/extern/include"
  "${MATLAB_ROOT}/simulink/include"
  "${MATLAB_ROOT}/rtw/c/src/matrixmath"
  "${MATLAB_ROOT}/rtw/c/src"
)

# modelDescription.xml
add_custom_command(TARGET ${MODEL_NAME}_sf POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy
  ${RTW_DIR}/modelDescription.xml
  ${FMU_BUILD_DIR}/modelDescription.xml
)

# shared library
add_custom_command(TARGET ${MODEL_NAME}_sf POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy
  $<TARGET_FILE:${MODEL_NAME}_sf>
  ${FMU_BUILD_DIR}/binaries/${FMI_PLATFORM}/$<TARGET_FILE_NAME:${MODEL_NAME}_sf>
)

# create ZIP archive
add_custom_command(TARGET ${MODEL_NAME}_sf POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E tar "cfv" ${RTW_DIR}/${MODEL_NAME}_sf.fmu --format=zip
  modelDescription.xml
  binaries
  WORKING_DIRECTORY ${FMU_BUILD_DIR}
)
