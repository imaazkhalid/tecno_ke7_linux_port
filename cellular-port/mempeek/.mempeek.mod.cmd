savedcmd_mempeek.mod := printf '%s\n'   mempeek.o | awk '!x[$$0]++ { print("./"$$0) }' > mempeek.mod
