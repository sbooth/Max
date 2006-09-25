JFLAGS+=-classpath /System/Library/Java

Source/com/growl/Growl.class: Source/com/growl/Growl.java
	javac $(JFLAGS) $^

.PHONY: install all clean

/Library/Java/com/growl:
	mkdir -p $@

install: Source/com/growl/Growl.class /Library/Java/com/growl
	cp $^

docs: Source/com/growl/Growl.java
	javadoc -d $@ $(JFLAGS) $^

all: docs Source/com/growl/Growl.class

clean:
	rm -f Source/com/growl/Growl.class
