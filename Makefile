CC?=	cc
CFLAGS= -Wall -g -fstack-protector 
TARGETS=	fdwatchd
OBJ=	fdwatchd.o y.tab.o lex.yy.o

all:	$(TARGETS)

.c.o:
	$(CC) $(CFLAGS) -c $<

lex.yy.o: y.tab.o token.l
	lex token.l
	$(CC) $(CFLAGS) -c lex.yy.c

y.tab.o: grammar.y
	yacc -vd grammar.y
	$(CC) $(CFLAGS) -c y.tab.c


fdwatchd:	$(OBJ)
		$(CC) $(CFLAGS) -o $@ $(OBJ)

clean:
	rm -fr fdwatchd *.o y.output y.tab.c y.tab.h *.core lex.yy.c *.out
