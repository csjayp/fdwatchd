%{
#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>

#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>

#include "fdwatchd.h"

extern int	 yylex(void);
extern void	 yyerror(const char *);
extern char	*yytext;

extern struct kevent	*kev;
extern int		 nkev;

void
yyerror(const char *str)
{
	extern int lineno;

	note(1, "file: %d syntax error near '%s'\n",
	    lineno, yytext);
	exit(1);
}

int
yywrap()
{
	return (1);
}
%}

%union {
	char		*str;
	unsigned int	 mask;
}

%token	QSTRING PATH EXEC OP OBRACE EBRACE SEMICOLON
%token	WRITE DELETE ATTRIB RENAME
%type	<str> QSTRING
%type	<mask> WRITE DELETE ATTRIB RENAME

%%

root	: /* empty */
	| root cmd
	;

cmd	:
	path_def
        ;

path_def:
	PATH QSTRING
	{
		struct kevent *kep;
		struct fdwatch *fw;
		int fd;

		fw = malloc(sizeof(*fw));
		if (fw == NULL) {
			note(1, "could not allocate fdwatch data\n");
			exit(1);
		}
		bzero(fw, sizeof(*fw));
		strcpy(fw->fdw_path, $2);
		kev = realloc(kev, (nkev + 1) * sizeof(*kep));
		if (kev == NULL) {
			note(1, "realloc operation failed: %s\n",
			    strerror(errno));
			exit(1);
		}
		kep = &kev[nkev];
		fd = open($2, O_RDONLY);
		if (fd == -1) {
			note(1, "open: %s failed: %s\n", $2,
			    strerror(errno));
			exit(1);
		}
		kep->ident = fd;
		kep->filter = EVFILT_VNODE;
		kep->flags = EV_ADD | EV_ONESHOT | EV_ENABLE;
		kep->fflags = 0;
		kep->data = 0;
		kep->udata = fw;
	}
	OBRACE path_block EBRACE
	{
		note(1, "registerd watch event for '%s'\n", $2);
		nkev++;
	}
	;

path_block:
	| path_block path_params
	;

path_params:
	OP WRITE SEMICOLON
	{
		struct kevent *kep;

		kep = &kev[nkev];
		kep->fflags |= $2;
	}
	| OP DELETE SEMICOLON
	{
		struct kevent *kep;

		kep = &kev[nkev];
		kep->fflags |= $2;
	}
	| OP RENAME SEMICOLON
	{
		struct kevent *kep;

		kep = &kev[nkev];
		kep->fflags |= $2;
	}
	| OP ATTRIB SEMICOLON
	{
		struct kevent *kep;

		kep = &kev[nkev];
		kep->fflags |= $2;
	}
	| EXEC QSTRING SEMICOLON
	{
		struct fdwatch *fp;
		struct kevent *kep;

		kep = &kev[nkev];
		fp = (struct fdwatch *)kep->udata;
		strcpy(fp->fdw_script, $2);
	}
	;
