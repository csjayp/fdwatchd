%{
/*-
 * Copyright (c) 2016 Christian S.J. Peron
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
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
%type	<mask> opspec

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

opspec:
	WRITE
	{
		$$ = NOTE_WRITE;
	}
	| DELETE
	{
		$$ = NOTE_DELETE;
	}
	| RENAME
	{
		$$ = NOTE_RENAME;
	}
	| ATTRIB
	{
		$$ = NOTE_ATTRIB;
	}
	;

path_params:
	OP opspec SEMICOLON
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
