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

#include "y.tab.h"
#define YY_NO_UNPUT

int lineno = 1;
%}

tokenchar	[^[:blank:];,<>"\n]
tokenstring	{tokenchar}+

%%
\n              lineno++;
[ \t]+          /* ignore whitespace */
\#.*            /* ignore comments */
path		return (PATH);
op		return (OP);
exec		return (EXEC);
write		{
			yylval.mask = NOTE_WRITE;
			return (WRITE);
		}
delete		{
			yylval.mask = NOTE_DELETE;
			return (DELETE);
		}
attrib		{
			yylval.mask = NOTE_ATTRIB;
			return (ATTRIB);
		}
rename		{
			yylval.mask = NOTE_RENAME;
			return (RENAME);
		}
\;		return (SEMICOLON);
\{		return (OBRACE);
\}		return (EBRACE);
\"              {
			char buf[1024], *ptr, c;
			int escaped;

			escaped = 0;
			bzero(buf, sizeof(buf));
			for (ptr = buf; strlen(buf) < (sizeof(buf) - 1);
			    ptr++) {
				c = input();
				if (escaped && c != EOF) {
					*ptr = c;
					escaped = 0;
					continue;
				}
				switch (c) {
				case '\\':
					ptr--;
					escaped = 1;
					break;
				case '\n':
					*ptr = ' ';
					lineno++;
					break;
				case '"':       /* end quote */
					ptr = NULL;
					break;
				case EOF:
					(void) fprintf(stderr, "unmatched \"\n");
					exit(1);
				default:
					*ptr = c;
					break;
				}
				if (ptr == NULL)
					break;
			}
			yylval.str = strdup(buf);
			return (QSTRING);
		}
{tokenstring}	{
			yylval.str = strdup(yytext);
			return (QSTRING);
		}
