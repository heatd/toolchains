set(ONYX 1)
set(UNIX 1)

set(CMAKE_DL_LIBS "")
set(CMAKE_C_COMPILE_OPTIONS_PIC "-fPIC")
set(CMAKE_C_COMPILE_OPTIONS_PIE "-fPIE")
set(_CMAKE_C_PIE_MAY_BE_SUPPORTED_BY_LINKER YES)
set(CMAKE_C_LINK_OPTIONS_PIE ${CMAKE_C_COMPILE_OPTIONS_PIE} "-pie")
set(CMAKE_C_LINK_OPTIONS_NO_PIE "-no-pie")
set(CMAKE_SHARED_LIBRARY_C_FLAGS "-fPIC")
set(CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS "-shared")
set(CMAKE_SHARED_LIBRARY_RUNTIME_C_FLAG "-Wl,-rpath,")
set(CMAKE_SHARED_LIBRARY_RUNTIME_C_FLAG_SEP ":")
set(CMAKE_SHARED_LIBRARY_RPATH_LINK_C_FLAG "-Wl,-rpath-link,")
set(CMAKE_SHARED_LIBRARY_SONAME_C_FLAG "-Wl,-soname,")
set(CMAKE_EXE_EXPORTS_C_FLAG "-Wl,--export-dynamic")

# Shared libraries with no builtin soname may not be linked safely by
# specifying the file path.
set(CMAKE_PLATFORM_USES_PATH_WHEN_NO_SONAME 1)

# Initialize C link type selection flags.  These flags are used when
# building a shared library, shared module, or executable that links
# to other libraries to select whether to use the static or shared
# versions of the libraries.
foreach(type SHARED_LIBRARY SHARED_MODULE EXE)
  set(CMAKE_${type}_LINK_STATIC_C_FLAGS "-Wl,-Bstatic")
  set(CMAKE_${type}_LINK_DYNAMIC_C_FLAGS "-Wl,-Bdynamic")
endforeach()

include(Platform/UnixPaths)
# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.


# Block multiple inclusion because "CMakeCInformation.cmake" includes
# "Platform/${CMAKE_SYSTEM_NAME}" even though the generic module
# "CMakeSystemSpecificInformation.cmake" already included it.
# The extra inclusion is a work-around documented next to the include()
# call, so this can be removed when the work-around is removed.
if(__UNIX_PATHS_INCLUDED)
  return()
endif()
set(__UNIX_PATHS_INCLUDED 1)

set(UNIX 1)

# also add the install directory of the running cmake to the search directories
# CMAKE_ROOT is CMAKE_INSTALL_PREFIX/share/cmake, so we need to go two levels up
get_filename_component(_CMAKE_INSTALL_DIR "${CMAKE_ROOT}" PATH)
get_filename_component(_CMAKE_INSTALL_DIR "${_CMAKE_INSTALL_DIR}" PATH)

# List common installation prefixes.  These will be used for all
# search types.
#
# Reminder when adding new locations computed from environment variables
# please make sure to keep Help/variable/CMAKE_SYSTEM_PREFIX_PATH.rst
# synchronized
list(APPEND CMAKE_SYSTEM_PREFIX_PATH
  # Standard
  /usr/local /usr /

  # CMake install location
  "${_CMAKE_INSTALL_DIR}"
  )
if (NOT CMAKE_FIND_NO_INSTALL_PREFIX)
  list(APPEND CMAKE_SYSTEM_PREFIX_PATH
    # Project install destination.
    "${CMAKE_INSTALL_PREFIX}"
  )
  if(CMAKE_STAGING_PREFIX)
    list(APPEND CMAKE_SYSTEM_PREFIX_PATH
      # User-supplied staging prefix.
      "${CMAKE_STAGING_PREFIX}"
    )
  endif()
endif()

# Non "standard" but common install prefixes
list(APPEND CMAKE_SYSTEM_PREFIX_PATH
  /usr/X11R6
  /usr/pkg
  /opt
  )

# List common include file locations not under the common prefixes.
list(APPEND CMAKE_SYSTEM_INCLUDE_PATH
  # X11
  /usr/include/X11
  )

list(APPEND CMAKE_SYSTEM_LIBRARY_PATH
  # X11
  /usr/lib/X11
  )

list(APPEND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES
  /lib /lib32 /lib64 /usr/lib /usr/lib32 /usr/lib64
  )

if(CMAKE_SYSROOT_COMPILE)
  set(_cmake_sysroot_compile "${CMAKE_SYSROOT_COMPILE}")
else()
  set(_cmake_sysroot_compile "${CMAKE_SYSROOT}")
endif()

# Default per-language values.  These may be later replaced after
# parsing the implicit directory information from compiler output.
set(_CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES_INIT
  ${CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES}
  "${_cmake_sysroot_compile}/usr/include"
  )
set(_CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES_INIT
  ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES}
  "${_cmake_sysroot_compile}/usr/include"
  )
set(_CMAKE_CUDA_IMPLICIT_INCLUDE_DIRECTORIES_INIT
  ${CMAKE_CUDA_IMPLICIT_INCLUDE_DIRECTORIES}
  "${_cmake_sysroot_compile}/usr/include"
  )

unset(_cmake_sysroot_compile)

# Reminder when adding new locations computed from environment variables
# please make sure to keep Help/variable/CMAKE_SYSTEM_PREFIX_PATH.rst
# synchronized
if(CMAKE_COMPILER_SYSROOT)
  list(PREPEND CMAKE_SYSTEM_PREFIX_PATH "${CMAKE_COMPILER_SYSROOT}")

  if(DEFINED ENV{CONDA_PREFIX} AND EXISTS "$ENV{CONDA_PREFIX}")
    list(APPEND CMAKE_SYSTEM_PREFIX_PATH "$ENV{CONDA_PREFIX}")
  endif()
endif()

# Enable use of lib32 and lib64 search path variants by default.
set_property(GLOBAL PROPERTY FIND_LIBRARY_USE_LIB32_PATHS TRUE)
set_property(GLOBAL PROPERTY FIND_LIBRARY_USE_LIB64_PATHS TRUE)
set_property(GLOBAL PROPERTY FIND_LIBRARY_USE_LIBX32_PATHS TRUE)

set(ENV{PKG_CONFIG_DIR} "")
set(ENV{PKG_CONFIG_LIBDIR} "${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} ${CMAKE_SYSROOT})
