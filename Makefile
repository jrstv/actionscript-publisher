MXMLC ?= "/Applications/Apache Flex4/bin/mxmlc"

all: checkforflexsdk web/recorder.swf

web/recorder.swf: recorder.as as3crypto.swc as3corelib.swc Makefile
	@${MXMLC} --library-path . -o $@ recorder.as

checkforflexsdk:
	@test -x ${MXMLC} || (echo "You must install the FLEX SDK!"; exit 1 )

clean:
	@$(RM) -f web/recorder.swf
