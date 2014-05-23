FLEX_PATH ?= /Applications/Apache\ Flex4
MXMLC ?= $(FLEX_PATH)/bin/mxmlc
FRAMEWORKS_PATH = $(FLEX_PATH)/frameworks/libs
LIBRARY_PATH ?= $(FRAMEWORKS_PATH)/core.swc $(FRAMEWORKS_PATH)/framework.swc lib/as3crypto.swc

all: checkforflexsdk web/publisher.swf

web/publisher.swf: publisher.as Makefile
	@$(MXMLC) --library-path $(LIBRARY_PATH) -o $@ publisher.as

checkforflexsdk:
	@test -x $(MXMLC) || (echo "Set FLEX_PATH or install the FLEX SDK!"; exit 1 )

clean:
	@$(RM) -f web/publisher.swf
