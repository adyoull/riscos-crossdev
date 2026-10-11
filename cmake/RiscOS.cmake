# include(RiscOS) in a project built with cmake/riscos.cmake:
#
#   riscos_checks(TARGET)
#       after each link, run checks/check-all.sh on the program (static,
#       stack probes, FPU level, UnixLib): the build fails if one fails.
#   riscos_aif(TARGET DESTINATION)
#       target TARGET-aif: the program stripped and converted to Absolute
#       (AIF, filetype &FF8) at DESTINATION, e.g. ${CMAKE_BINARY_DIR}/!App/!RunImage,ff8
#       (built with `cmake --build build --target TARGET-aif`, or ALL).
get_filename_component(_rcd_dir "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

function(riscos_checks target)
  add_custom_command(TARGET ${target} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E env "RISCOS_TOOLCHAIN=${RISCOS_TOOLCHAIN}"
            "${_rcd_dir}/checks/check-all.sh" "$<TARGET_FILE:${target}>"
    COMMENT "RISC OS checks: ${target}" VERBATIM)
endfunction()

function(riscos_aif target destination)
  get_filename_component(dir "${destination}" DIRECTORY)
  add_custom_command(OUTPUT "${destination}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${dir}"
    COMMAND "${CMAKE_STRIP}" -o "$<TARGET_FILE:${target}>.stripped" "$<TARGET_FILE:${target}>"
    COMMAND "${RISCOS_ELF2AIF}" -e "$<TARGET_FILE:${target}>.stripped" "${destination}"
    DEPENDS ${target}
    COMMENT "AIF: ${destination}" VERBATIM)
  add_custom_target(${target}-aif ALL DEPENDS "${destination}")
endfunction()
