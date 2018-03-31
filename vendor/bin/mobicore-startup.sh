#!/system/bin/sh

# Startup script for MobiCore processes #
mobicore=`getprop sys.mobicore.vendor.enable`

if [ "$mobicore" -eq "true" ]; then
	echo "running mobicore daemon in background (vendor)"
	# run daemon in background
	/vendor/bin/mcDriverDaemon -b
else
	echo "mobicore is not ready"
	exit 1
fi
