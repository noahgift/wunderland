#!/bin/sh
cd `dirname $0`
make
if [ ! -f ebin/rest_app.boot ]; then
	make boot
fi
erl -pa $PWD/ebin -pa $PWD/deps/*/ebin -sname alice -s reloader -boot alice $*
