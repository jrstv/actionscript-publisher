MXMLC ?= "/Applications/Apache Flex4/bin/mxmlc"

recorder.swf: checkforflexsdk producer.as as3crypto.swc as3corelib.swc Makefile
	@${MXMLC} --library-path . -o $@ producer.as

checkforflexsdk:
	@test -x ${MXMLC} || (echo "You must install the FLEX SDK!"; exit 1 )

clean:
	@$(RM) -f recorder.swf
