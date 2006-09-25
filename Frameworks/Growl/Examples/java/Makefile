JFLAGS+=-classpath /System/Library/Java:/Library/Java

jnotify.class: jnotify.java
	javac $(JFLAGS) $^

.PHONY: all clean

docs: jnotify.java
	javadoc -d $@ $(JFLAGS) $^

all: docs jnotify.class

clean:
	rm -f *.class
